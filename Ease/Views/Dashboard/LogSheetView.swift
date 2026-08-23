import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct LogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.date, order: .forward) private var records: [DailyRecord]
    @Query(sort: \WeightLog.timestamp, order: .forward) private var weightLogs: [WeightLog]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    let mode: LogSheetMode
    @State private var selectedDate: Date
    @State private var editingLogID: UUID?
    @State private var weightText: String
    @State private var bodyFatText: String
    @State private var diet: DietStatus?
    @State private var tags: Set<VariableTag>
    @State private var noteText: String
    @State private var errorKey: String?
    @State private var errorPulse = 0
    @State private var saveSuccessPulse = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var isOCRBusy = false
    @State private var isCalendarExpanded = false

    init(date: Date, editingLogID: UUID? = nil, mode: LogSheetMode = .weight) {
        self.mode = mode
        let start = CalendarDay.startOfDay(date)
        _selectedDate = State(initialValue: start)
        _editingLogID = State(initialValue: editingLogID)
        _weightText = State(initialValue: "")
        _bodyFatText = State(initialValue: "")
        _diet = State(initialValue: nil)
        _tags = State(initialValue: [])
        _noteText = State(initialValue: "")
    }

    private var existing: DailyRecord? {
        let key = CalendarDay.dayKey(from: selectedDate)
        return records.first { $0.dayKey == key }
    }

    private var titleKey: LocalizedStringKey {
        switch mode {
        case .weight: "log.title.weight"
        case .diet: "log.title.diet"
        }
    }

    private var dietSelectionToken: String {
        diet?.rawValue ?? "none"
    }

    private var tagSelectionToken: Int {
        tags.map(\.rawValue).sorted().joined().hashValue
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard(radius: 16, padding: 18) {
                            logDateRow
                        }
                        switch mode {
                        case .weight:
                            weightCard
                        case .diet:
                            dietCard
                            tagsCard
                            noteCard
                        }
                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EasePalette.primaryText)
                        }
                        EasePrimaryButton(
                            title: "log.save",
                            isEnabled: canSave,
                            usesAccent: true,
                            action: save
                        )
                        if showsDelete {
                            EaseTextButton(title: "log.delete", action: deleteCurrent)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(Text("common.close"))
                }
            }
            .onAppear(perform: hydrateFromExisting)
            .onChange(of: selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    editingLogID = nil
                }
                hydrateFromExisting()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await applyOCR(from: item) }
            }
            .photosPicker(isPresented: $isPhotoPickerPresented, selection: $photoItem, matching: .images)
            .sensoryFeedback(.error, trigger: errorPulse)
            .sensoryFeedback(.success, trigger: saveSuccessPulse)
            .sensoryFeedback(.selection, trigger: dietSelectionToken)
            .sensoryFeedback(.selection, trigger: tagSelectionToken)
        }
        .preferredColorScheme(.light)
    }

    private var weightCard: some View {
        EaseCard(radius: 16, padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("log.weight")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("onboarding.weight.placeholder", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .minimumScaleFactor(0.5)
                    Text("unit.kg")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 8)
                    ocrButton
                }

                Divider().overlay(EasePalette.hairline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("log.bodyFat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("log.bodyFat.placeholder", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(EasePalette.primaryText)
                        Text("unit.percent")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var dietCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("log.diet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(DietStatus.allCases, id: \.self) { status in
                        dietChip(status)
                    }
                }
                .animation(.snappy, value: dietSelectionToken)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tagsCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("log.tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(VariableTag.allCases, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
                .animation(.snappy, value: tagSelectionToken)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteCard: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("log.note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("log.note.placeholder", text: $noteText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(EasePalette.primaryText)
                    .lineLimit(3...6)
            }
        }
    }

    private var logDateRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCalendarExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("log.date")
                        .font(.body)
                        .foregroundStyle(EasePalette.primaryText)
                    Spacer(minLength: 12)
                    Text(EaseFormatters.numericDate(selectedDate))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                    Image(systemName: isCalendarExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("log.date.hint"))

            if isCalendarExpanded {
                DatePicker(
                    "log.date",
                    selection: $selectedDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(EasePalette.accent)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var editingLog: WeightLog? {
        guard let editingLogID else { return nil }
        return weightLogs.first { $0.id == editingLogID }
    }

    private var showsDelete: Bool {
        switch mode {
        case .weight:
            return editingLog != nil
        case .diet:
            return existing != nil
        }
    }

    private var canSave: Bool {
        switch mode {
        case .weight:
            return EaseFormatters.parseDecimal(weightText) != nil
        case .diet:
            return diet != nil || !tags.isEmpty || !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || existing != nil
        }
    }

    private var ocrButton: some View {
        Button {
            Task {
                await PermissionsService.requestPhotoLibrary()
                isPhotoPickerPresented = true
            }
        } label: {
            ZStack {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(EasePalette.accent)
                    .opacity(isOCRBusy ? 0 : 1)
                if isOCRBusy {
                    ProgressView()
                        .tint(EasePalette.accent)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(isOCRBusy)
        .accessibilityLabel(Text("log.ocr"))
    }

    private func applyOCR(from item: PhotosPickerItem) async {
        isOCRBusy = true
        defer {
            isOCRBusy = false
            photoItem = nil
        }
        guard let picked = try? await item.loadTransferable(type: PickedScaleImage.self) else { return }
        let result = await ScaleOCR.recognize(image: picked.image)
        if let weight = result.weightKg {
            weightText = EaseFormatters.oneDecimal(weight)
        }
        if let bodyFat = result.bodyFatPercent {
            bodyFatText = EaseFormatters.oneDecimal(bodyFat)
        }
    }

    private func dietChip(_ status: DietStatus) -> some View {
        let selected = diet == status
        let tint = EasePalette.dietTint(status)
        return Button {
            diet = selected ? nil : status
        } label: {
            HStack(spacing: 6) {
                Image(systemName: status.systemImage)
                Text(LocalizedStringKey(status.titleKey))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? tint : EasePalette.secondaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                selected ? tint.opacity(0.18) : EasePalette.recessed,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func tagChip(_ tag: VariableTag) -> some View {
        let selected = tags.contains(tag)
        return Button {
            if selected { tags.remove(tag) } else { tags.insert(tag) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tag.systemImage)
                Text(LocalizedStringKey(tag.titleKey))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? EasePalette.accent : EasePalette.secondaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                selected ? EasePalette.accent.opacity(0.16) : EasePalette.recessed,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func hydrateFromExisting() {
        let record = existing
        let log = editingLog ?? loadEditingLog()
        if mode == .weight {
            if let log {
                weightText = EaseFormatters.oneDecimal(log.weight)
                bodyFatText = log.bodyFat.map(EaseFormatters.oneDecimal) ?? ""
            } else {
                weightText = ""
                bodyFatText = ""
            }
        }
        if mode == .diet {
            diet = record?.dietStatus
            tags = Set(record?.variableTags ?? [])
            noteText = record?.note ?? ""
        }
        errorKey = nil
    }

    private func loadEditingLog() -> WeightLog? {
        guard let editingLogID else { return nil }
        return try? WeightLogRepository(context: modelContext).log(id: editingLogID)
    }

    private func save() {
        do {
            switch mode {
            case .weight:
                let weight = EaseFormatters.parseDecimal(weightText)
                let bodyFat = EaseFormatters.parseDecimal(bodyFatText)
                guard weight != nil else {
                    presentError("log.error.empty")
                    return
                }
                try saveWeight(weight: weight, bodyFat: bodyFat)
            case .diet:
                let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                let noteValue = note.isEmpty ? nil : note
                guard diet != nil || !tags.isEmpty || noteValue != nil || existing != nil else {
                    presentError("log.error.empty")
                    return
                }
                try saveJournal(note: noteValue)
            }
            saveSuccessPulse += 1
            refreshReminders()
            dismiss()
        } catch let error as EaseDataError {
            switch error {
            case .emptyRecord, .emptyPatch:
                presentError("log.error.empty")
            case .invalidWeight, .invalidBodyFat, .invalidProfile, .invalidMetric, .tooManyCustomMetrics:
                presentError("onboarding.error.invalid")
            case .futureDate:
                presentError("log.error.future")
            }
        } catch {
            presentError("onboarding.error.invalid")
        }
    }

    private func saveWeight(weight: Double?, bodyFat: Double?) throws {
        let logs = WeightLogRepository(context: modelContext)
        if let editingLog {
            guard let weight else { return }
            try logs.update(editingLog, weight: weight, bodyFat: bodyFat)
            return
        }
        guard let weight else { return }
        try logs.insert(timestamp: timestampForNewLog, weight: weight, bodyFat: bodyFat)
    }

    private var timestampForNewLog: Date {
        if Calendar.current.isDate(selectedDate, inSameDayAs: .now) {
            return .now
        }
        return CalendarDay.atHour(8, on: selectedDate)
    }

    private func saveJournal(note: String?) throws {
        var patch = DailyRecordPatch()
        patch.dietStatus = .set(diet)
        patch.tags = .set(VariableTag.sanitized(Array(tags)))
        patch.note = .set(note)
        try DailyRecordRepository(context: modelContext).upsert(on: selectedDate, patch: patch)
    }

    private func presentError(_ key: String) {
        errorKey = key
        errorPulse += 1
    }

    private func deleteCurrent() {
        do {
            switch mode {
            case .weight:
                if let editingLog {
                    try WeightLogRepository(context: modelContext).delete(editingLog)
                }
            case .diet:
                try DailyRecordRepository(context: modelContext).delete(on: selectedDate)
            }
            refreshReminders()
            dismiss()
        } catch {
            presentError("onboarding.error.invalid")
        }
    }

    private func refreshReminders() {
        let enabled = profiles.first?.notificationsEnabled == true
        Task {
            await NotificationScheduler.refresh(enabled: enabled, context: modelContext)
        }
    }
}

private struct PickedScaleImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return PickedScaleImage(image: image)
        }
    }
}
