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

    @State private var selectedDate: Date
    @State private var editingLogID: UUID?
    @State private var weightText: String
    @State private var bodyFatText: String
    @State private var diet: DietStatus?
    @State private var tags: Set<VariableTag>
    @State private var noteText: String
    @State private var errorKey: String?
    @State private var errorPulse = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var isOCRBusy = false

    init(date: Date, editingLogID: UUID? = nil) {
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

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard {
                            logDateRow
                        }
                        EaseCard {
                            VStack(spacing: 20) {
                                EaseField(
                                    title: "log.weight",
                                    placeholder: "onboarding.weight.placeholder",
                                    text: $weightText,
                                    suffix: "unit.kg",
                                    isInvalid: isNumericError
                                ) {
                                    ocrButton
                                }
                                EaseField(
                                    title: "log.bodyFat",
                                    placeholder: "log.bodyFat.placeholder",
                                    text: $bodyFatText,
                                    suffix: "unit.percent",
                                    isInvalid: isNumericError
                                )
                            }
                        }
                        EaseCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("log.diet")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                HStack(spacing: 8) {
                                    ForEach(DietStatus.allCases, id: \.self) { status in
                                        dietChip(status)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        EaseCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("log.tags")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                HStack(spacing: 8) {
                                    ForEach(VariableTag.allCases, id: \.self) { tag in
                                        tagChip(tag)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        EaseCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("log.note")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                TextField("log.note.placeholder", text: $noteText, axis: .vertical)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(EasePalette.primaryText)
                                    .lineLimit(3...6)
                            }
                        }
                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(EasePalette.primaryText)
                        }
                        EasePrimaryButton(title: "log.save", isEnabled: canSave, action: save)
                        if showsDelete {
                            EaseTextButton(title: "log.delete", action: deleteCurrent)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("log.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
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
        }
        .preferredColorScheme(.light)
    }

    private var logDateRow: some View {
        HStack {
            Text("log.date")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(EasePalette.primaryText)
            Spacer(minLength: 12)
            Text(EaseFormatters.numericDate(selectedDate))
                .font(.system(size: 16, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
                .frame(minWidth: 120, minHeight: 32, alignment: .trailing)
                .overlay {
                    DatePicker(
                        "log.date",
                        selection: $selectedDate,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(EasePalette.accent)
                    .opacity(0.02)
                }
        }
    }

    private var isNumericError: Bool {
        errorKey == "onboarding.error.invalid"
    }

    private var logsOnSelectedDay: [WeightLog] {
        let key = CalendarDay.dayKey(from: selectedDate)
        return weightLogs.filter { CalendarDay.dayKey(from: $0.timestamp) == key }
    }

    private var editingLog: WeightLog? {
        guard let editingLogID else { return nil }
        return weightLogs.first { $0.id == editingLogID }
    }

    private var showsDelete: Bool {
        editingLog != nil || (existing != nil && logsOnSelectedDay.isEmpty)
    }

    private var canSave: Bool {
        let hasWeight = EaseFormatters.parseDecimal(weightText) != nil
        return hasWeight || diet != nil
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
        return Button {
            diet = selected ? nil : status
        } label: {
            HStack(spacing: 6) {
                Image(systemName: status.systemImage)
                Text(LocalizedStringKey(status.titleKey))
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(selected ? Color.white : EasePalette.primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(selected ? Color.black : EasePalette.track)
            .clipShape(Capsule())
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
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(selected ? Color.white : EasePalette.primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(selected ? EasePalette.accent : EasePalette.track)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func hydrateFromExisting() {
        let record = existing
        let log = editingLog ?? loadEditingLog()
        if let log {
            weightText = EaseFormatters.oneDecimal(log.weight)
            bodyFatText = log.bodyFat.map(EaseFormatters.oneDecimal) ?? ""
        } else {
            weightText = ""
            bodyFatText = ""
        }
        diet = record?.dietStatus
        tags = Set(record?.variableTags ?? [])
        noteText = record?.note ?? ""
        errorKey = nil
    }

    private func loadEditingLog() -> WeightLog? {
        guard let editingLogID else { return nil }
        return try? WeightLogRepository(context: modelContext).log(id: editingLogID)
    }

    private func save() {
        let weight = EaseFormatters.parseDecimal(weightText)
        let bodyFat = EaseFormatters.parseDecimal(bodyFatText)
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteValue = note.isEmpty ? nil : note
        guard weight != nil || diet != nil else {
            presentError("log.error.empty")
            return
        }
        do {
            try saveWeight(weight: weight, bodyFat: bodyFat)
            try saveJournal(note: noteValue)
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
            let fatUnchanged = editingLog.weight == weight && editingLog.bodyFat == bodyFat
            if fatUnchanged { return }
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
        let hasJournal = diet != nil || !tags.isEmpty || note != nil || existing != nil
        guard hasJournal else { return }
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
            if let editingLog {
                try WeightLogRepository(context: modelContext).delete(editingLog)
            } else if logsOnSelectedDay.isEmpty {
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
