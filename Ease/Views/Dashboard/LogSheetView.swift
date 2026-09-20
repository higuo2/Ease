import SwiftUI
import SwiftData

private enum WeightDaypart: String, CaseIterable, Identifiable {
    case morning
    case evening

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .morning: "history.morning"
        case .evening: "history.evening"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sun.max.fill"
        case .evening: "moon.fill"
        }
    }

    var hour: Int {
        switch self {
        case .morning: 8
        case .evening: 20
        }
    }

    static func from(date: Date, calendar: Calendar = .current) -> WeightDaypart {
        calendar.component(.hour, from: date) < 12 ? .morning : .evening
    }
}

struct LogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightLog.timestamp, order: .forward) private var weightLogs: [WeightLog]
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]

    @State private var selectedDate: Date
    @State private var daypart: WeightDaypart
    @State private var editingLogID: UUID?
    @State private var weightText: String
    @State private var bodyFatText: String
    @State private var errorKey: String?
    @State private var errorPulse = 0
    @State private var saveSuccessPulse = 0
    @State private var isCalendarExpanded = false

    init(date: Date, editingLogID: UUID? = nil) {
        let start = CalendarDay.startOfDay(date)
        _selectedDate = State(initialValue: start)
        _editingLogID = State(initialValue: editingLogID)
        _weightText = State(initialValue: "")
        _bodyFatText = State(initialValue: "")
        _daypart = State(initialValue: WeightDaypart.from(date: .now))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        EaseCard(radius: 16, padding: 18) {
                            logDateRow
                        }

                        heroWeightCard

                        bodyFatCard

                        if let errorKey {
                            Text(LocalizedStringKey(errorKey))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EasePalette.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                stickySaveBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
                ToolbarItem(placement: .principal) {
                    Text("log.title.weight")
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .onAppear(perform: hydrateFromExisting)
            .onChange(of: selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    editingLogID = nil
                }
                hydrateFromExisting()
            }
            .sensoryFeedback(.error, trigger: errorPulse)
            .sensoryFeedback(.success, trigger: saveSuccessPulse)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.accent)
    }

    private var stickySaveBar: some View {
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
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var heroWeightCard: some View {
        EaseCard(radius: 20, padding: 22) {
            VStack(spacing: 18) {
                daypartPicker

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Spacer(minLength: 0)
                    TextField("onboarding.weight.placeholder", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.45)
                        .frame(maxWidth: 220)
                    Text("unit.kg")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("log.weight"))
            }
        }
    }

    private var daypartPicker: some View {
        HStack(spacing: 8) {
            ForEach(WeightDaypart.allCases) { part in
                let selected = daypart == part
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        daypart = part
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: part.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(part.titleKey)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected ? Color.white : EasePalette.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        selected ? EasePalette.morandiRedDeep : EasePalette.recessed,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var bodyFatCard: some View {
        EaseCard(radius: 16, padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "percent")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(EasePalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(
                        EasePalette.recessed,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .accessibilityHidden(true)

                Text("log.bodyFat")
                    .font(.body.weight(.medium))
                    .foregroundStyle(EasePalette.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    TextField("log.bodyFat.placeholder", text: $bodyFatText)
                        .keyboardType(.decimalPad)
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
                    Text("unit.percent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("log.bodyFat"))
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

    private var timestampForLog: Date {
        let candidate: Date
        if Calendar.current.isDate(selectedDate, inSameDayAs: .now) {
            let nowPart = WeightDaypart.from(date: .now)
            if nowPart == daypart {
                candidate = .now
            } else {
                candidate = CalendarDay.atHour(daypart.hour, on: selectedDate)
            }
        } else {
            candidate = CalendarDay.atHour(daypart.hour, on: selectedDate)
        }
        return min(candidate, .now)
    }

    private func hydrateFromExisting() {
        let log = editingLog ?? loadEditingLog()
        if let log {
            weightText = EaseFormatters.oneDecimal(log.weight)
            bodyFatText = log.bodyFat.map(EaseFormatters.oneDecimal) ?? ""
            daypart = WeightDaypart.from(date: log.timestamp)
        } else {
            weightText = ""
            bodyFatText = ""
            if Calendar.current.isDate(selectedDate, inSameDayAs: .now) {
                daypart = WeightDaypart.from(date: .now)
            } else {
                daypart = .morning
            }
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
        let stamp = timestampForLog
        if let editingLog {
            guard let weight else { return }
            editingLog.timestamp = stamp
            try logs.update(editingLog, weight: weight, bodyFat: bodyFat)
            return
        }
        guard let weight else { return }
        try logs.insert(timestamp: stamp, weight: weight, bodyFat: bodyFat)
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
