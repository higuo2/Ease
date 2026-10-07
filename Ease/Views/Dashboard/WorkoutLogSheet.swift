import SwiftUI
import SwiftData

private enum WorkoutSheetField: Hashable {
    case kcal
    case duration
}

struct WorkoutLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLog.timestamp, order: .forward) private var workoutLogs: [WorkoutLog]

    @State private var selectedDate: Date
    @State private var editingLogID: UUID?
    @State private var kcalText: String
    @State private var durationText: String
    @State private var errorKey: String?
    @State private var errorPulse = 0
    @State private var saveSuccessPulse = 0
    @State private var isCalendarExpanded = false
    @FocusState private var focusedField: WorkoutSheetField?

    init(date: Date, editingLogID: UUID? = nil) {
        _selectedDate = State(initialValue: CalendarDay.startOfDay(date))
        _editingLogID = State(initialValue: editingLogID)
        _kcalText = State(initialValue: "")
        _durationText = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background
                    .ignoresSafeArea()
                    .onTapGesture { resignInputFocus() }
                ScrollView {
                    VStack(spacing: 16) {
                        EaseCard(radius: 16, padding: 18) {
                            dateCard
                        }

                        heroKcalCard

                        durationCard

                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EasePalette.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        if showsDelete {
                            EaseTextButton(title: "log.delete", action: deleteCurrent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseCloseToolbarButton(action: closeSheet)
                }
                ToolbarItem(placement: .principal) {
                    Text("workout.title")
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    EaseToolbarSaveButton(isEnabled: canSave, action: save)
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .onAppear(perform: hydrateFromExisting)
            .sensoryFeedback(.error, trigger: errorPulse)
            .sensoryFeedback(.success, trigger: saveSuccessPulse)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.accent)
    }

    private var editingLog: WorkoutLog? {
        guard let editingLogID else { return nil }
        return workoutLogs.first { $0.id == editingLogID }
    }

    private var showsDelete: Bool { editingLog != nil }

    private var canSave: Bool {
        EaseFormatters.parseUnrounded(kcalText) != nil
    }

    private var timestampForLog: Date {
        let candidate: Date
        if Calendar.current.isDate(selectedDate, inSameDayAs: .now) {
            candidate = .now
        } else {
            candidate = CalendarDay.atHour(8, on: selectedDate)
        }
        return min(candidate, .now)
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                resignInputFocus()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCalendarExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    TrendModuleGlyph(systemName: "calendar", tint: EasePalette.iconEnergy)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("log.date")
                            .font(.body.weight(.medium))
                            .foregroundStyle(EasePalette.primaryText)
                        Text("log.date.hint")
                            .font(.caption)
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Text(EaseFormatters.numericDate(selectedDate))
                        .font(.body.weight(.semibold).monospacedDigit())
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

    private var heroKcalCard: some View {
        EaseCard(radius: 20, padding: 22) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    TrendModuleGlyph(systemName: "flame.fill", tint: EasePalette.iconEnergy)
                    Text("workout.kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EasePalette.primaryText)
                    Spacer(minLength: 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Spacer(minLength: 0)
                    TextField("workout.kcal.placeholder", text: $kcalText)
                        .focused($focusedField, equals: .kcal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.45)
                        .frame(maxWidth: 220)
                    Text("unit.kcal")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("workout.kcal"))
            }
        }
    }

    private var durationCard: some View {
        EaseCard(radius: 16, padding: 14) {
            HStack(spacing: 12) {
                TrendModuleGlyph(systemName: "clock", tint: EasePalette.iconEnergy)
                VStack(alignment: .leading, spacing: 2) {
                    Text("workout.duration")
                        .font(.body.weight(.medium))
                        .foregroundStyle(EasePalette.primaryText)
                        .lineLimit(1)
                    Text("workout.duration.placeholder")
                        .font(.caption)
                        .foregroundStyle(EasePalette.secondaryText)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    TextField("workout.duration.placeholder", text: $durationText)
                        .focused($focusedField, equals: .duration)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .frame(minWidth: 52, maxWidth: 72)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            EasePalette.recessed,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    Text("unit.minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("workout.duration"))
        }
    }

    private func hydrateFromExisting() {
        let log = editingLog ?? loadEditingLog()
        if let log {
            selectedDate = CalendarDay.startOfDay(log.timestamp)
            kcalText = String(Int(log.kcal.rounded()))
            durationText = log.durationMinutes.map(String.init) ?? ""
        }
        errorKey = nil
    }

    private func loadEditingLog() -> WorkoutLog? {
        guard let editingLogID else { return nil }
        return try? WorkoutLogRepository(context: modelContext).log(id: editingLogID)
    }

    private func parsedDuration() -> Int? {
        let trimmed = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = EaseFormatters.parseUnrounded(trimmed) else { return nil }
        return Int(value.rounded())
    }

    private func resignInputFocus() {
        focusedField = nil
        EaseKeyboard.dismiss()
    }

    private func closeSheet() {
        resignInputFocus()
        dismissAfterKeyboard()
    }

    private func dismissAfterKeyboard() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            dismiss()
        }
    }

    private func save() {
        resignInputFocus()
        do {
            guard let kcal = EaseFormatters.parseUnrounded(kcalText) else {
                presentError("log.error.empty")
                return
            }
            let trimmedDuration = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedDuration.isEmpty, parsedDuration() == nil {
                presentError("onboarding.error.invalid")
                return
            }
            try saveWorkout(kcal: kcal, durationMinutes: parsedDuration())
            saveSuccessPulse += 1
            dismissAfterKeyboard()
        } catch let error as EaseDataError {
            switch error {
            case .emptyRecord, .emptyPatch:
                presentError("log.error.empty")
            case .invalidWeight, .invalidBodyFat, .invalidProfile, .invalidMetric, .tooManyCustomMetrics, .invalidWorkout:
                presentError("onboarding.error.invalid")
            case .futureDate:
                presentError("log.error.future")
            }
        } catch {
            presentError("onboarding.error.invalid")
        }
    }

    private func saveWorkout(kcal: Double, durationMinutes: Int?) throws {
        let logs = WorkoutLogRepository(context: modelContext)
        let stamp = timestampForLog
        if let editingLog {
            editingLog.timestamp = stamp
            try logs.update(editingLog, kcal: kcal, durationMinutes: durationMinutes)
            return
        }
        try logs.insert(timestamp: stamp, kcal: kcal, durationMinutes: durationMinutes)
    }

    private func deleteCurrent() {
        guard let editingLog else { return }
        try? WorkoutLogRepository(context: modelContext).delete(editingLog)
        dismissAfterKeyboard()
    }

    private func presentError(_ key: String) {
        errorKey = key
        errorPulse += 1
    }
}
