import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct LogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightLog.timestamp, order: .forward) private var weightLogs: [WeightLog]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    @State private var selectedDate: Date
    @State private var editingLogID: UUID?
    @State private var weightText: String
    @State private var bodyFatText: String
    @State private var errorKey: String?
    @State private var errorPulse = 0
    @State private var saveSuccessPulse = 0
    @State private var ocrSuccessPulse = 0
    @State private var ocrPhotoItem: PhotosPickerItem?
    @State private var isOCRPickerPresented = false
    @State private var isOCRBusy = false
    @State private var isCalendarExpanded = false

    init(date: Date, editingLogID: UUID? = nil) {
        let start = CalendarDay.startOfDay(date)
        _selectedDate = State(initialValue: start)
        _editingLogID = State(initialValue: editingLogID)
        _weightText = State(initialValue: "")
        _bodyFatText = State(initialValue: "")
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
                        weightCard
                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EasePalette.primaryText)
                        }
                    }
                    .padding(20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
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
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(EasePalette.background.ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle("log.title.weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
            }
            .onAppear(perform: hydrateFromExisting)
            .onChange(of: selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    editingLogID = nil
                }
                hydrateFromExisting()
            }
            .onChange(of: ocrPhotoItem) { _, item in
                guard let item else { return }
                Task { await applyOCR(from: item) }
            }
            .photosPicker(isPresented: $isOCRPickerPresented, selection: $ocrPhotoItem, matching: .images)
            .sensoryFeedback(.error, trigger: errorPulse)
            .sensoryFeedback(.success, trigger: saveSuccessPulse)
            .sensoryFeedback(.success, trigger: ocrSuccessPulse)
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

    private var showsDelete: Bool { editingLog != nil }

    private var canSave: Bool {
        EaseFormatters.parseDecimal(weightText) != nil
    }

    private var ocrButton: some View {
        Button {
            isOCRPickerPresented = true
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
            ocrPhotoItem = nil
        }
        guard let picked = try? await item.loadTransferable(type: PickedUIImage.self) else { return }
        let result = await ScaleOCR.recognize(image: picked.image)
        if let weight = result.weightKg {
            weightText = EaseFormatters.oneDecimal(weight)
        }
        if let bodyFat = result.bodyFatPercent {
            bodyFatText = EaseFormatters.oneDecimal(bodyFat)
        }
        if result.weightKg != nil || result.bodyFatPercent != nil {
            ocrSuccessPulse += 1
        }
    }

    private func hydrateFromExisting() {
        let log = editingLog ?? loadEditingLog()
        if let log {
            weightText = EaseFormatters.oneDecimal(log.weight)
            bodyFatText = log.bodyFat.map(EaseFormatters.oneDecimal) ?? ""
        } else {
            weightText = ""
            bodyFatText = ""
        }
        errorKey = nil
    }

    private func loadEditingLog() -> WeightLog? {
        guard let editingLogID else { return nil }
        return try? WeightLogRepository(context: modelContext).log(id: editingLogID)
    }

    private func save() {
        do {
            let weight = EaseFormatters.parseDecimal(weightText)
            let bodyFat = EaseFormatters.parseDecimal(bodyFatText)
            guard weight != nil else {
                presentError("log.error.empty")
                return
            }
            try saveWeight(weight: weight, bodyFat: bodyFat)
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

    private func presentError(_ key: String) {
        errorKey = key
        errorPulse += 1
    }

    private func deleteCurrent() {
        do {
            if let editingLog {
                try WeightLogRepository(context: modelContext).delete(editingLog)
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
