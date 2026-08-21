import SwiftUI
import SwiftData

struct MetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricDefinition.sortOrder, order: .forward) private var metricDefinitions: [MetricDefinition]
    @Query(sort: \MetricLog.timestamp, order: .forward) private var metricLogs: [MetricLog]

    @State private var selectedDate: Date
    @State private var selectedKey: String
    @State private var metricTexts: [String: String] = [:]
    @State private var invalidKeys: Set<String> = []
    @State private var errorKey: String?
    @State private var errorPulse = 0

    init(date: Date, initialKey: String? = nil) {
        _selectedDate = State(initialValue: CalendarDay.startOfDay(date))
        _selectedKey = State(initialValue: initialKey ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard {
                            dateRow
                        }
                        if !enabledMetrics.isEmpty {
                            EaseCard {
                                VStack(spacing: 20) {
                                    ForEach(enabledMetrics, id: \.key) { definition in
                                        metricField(definition)
                                    }
                                }
                            }
                            if let errorKey {
                                Text(LocalizedStringKey(errorKey))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(EasePalette.primaryText)
                            }
                            EasePrimaryButton(title: "log.save", isEnabled: canSave, action: save)
                        } else {
                            EaseCard {
                                Text("metric.sheet.empty")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        historyListCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("metric.sheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .onAppear {
                if selectedKey.isEmpty || !historyDefinitions.contains(where: { $0.key == selectedKey }) {
                    selectedKey = historyDefinitions.first?.key ?? ""
                }
            }
            .onChange(of: selectedDate) { _, _ in
                metricTexts = [:]
                invalidKeys = []
                errorKey = nil
            }
            .sensoryFeedback(.error, trigger: errorPulse)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.accent)
    }

    private var enabledMetrics: [MetricDefinition] {
        metricDefinitions.filter { $0.isEnabled && MetricCatalog.isActiveMetricKey($0.key) }
    }

    private var historyDefinitions: [MetricDefinition] {
        var seen = Set<String>()
        var result: [MetricDefinition] = []
        let extras = metricDefinitions.filter {
            $0.key == selectedKey && MetricCatalog.isActiveMetricKey($0.key)
        }
        for definition in enabledMetrics + extras {
            if seen.insert(definition.key).inserted {
                result.append(definition)
            }
        }
        return result
    }

    private var selectedDefinition: MetricDefinition? {
        historyDefinitions.first { $0.key == selectedKey } ?? historyDefinitions.first
    }

    private var series: [MetricLog] {
        guard let selectedDefinition else { return [] }
        return metricLogs
            .filter { $0.metricKey == selectedDefinition.key }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var canSave: Bool {
        enabledMetrics.contains { definition in
            EaseFormatters.parseUnrounded(metricTexts[definition.key] ?? "") != nil
        }
    }

    private var timestampForNewLog: Date {
        if Calendar.current.isDate(selectedDate, inSameDayAs: .now) {
            return .now
        }
        return CalendarDay.atHour(8, on: selectedDate)
    }

    private var dateRow: some View {
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

    private func metricField(_ definition: MetricDefinition) -> some View {
        let spec = MetricCatalog.spec(for: definition)
        let key = definition.key
        return EaseField(
            title: LocalizedStringKey(spec.titleKey ?? "settings.metrics"),
            titleVerbatim: spec.kind == .custom ? spec.resolvedTitle : nil,
            placeholder: "log.bodyFat.placeholder",
            text: Binding(
                get: { metricTexts[key] ?? "" },
                set: {
                    metricTexts[key] = $0
                    invalidKeys.remove(key)
                }
            ),
            suffix: LocalizedStringKey(spec.unit.titleKey),
            isInvalid: invalidKeys.contains(key)
        )
    }

    private func save() {
        var drafts: [MetricLogDraft] = []
        var invalid: Set<String> = []
        for definition in enabledMetrics {
            let rawText = metricTexts[definition.key] ?? ""
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let raw = EaseFormatters.parseUnrounded(trimmed) else {
                invalid.insert(definition.key)
                continue
            }
            let spec = MetricCatalog.spec(for: definition)
            do {
                let value = try MetricCatalog.validated(raw, spec: spec)
                drafts.append(
                    MetricLogDraft(
                        timestamp: timestampForNewLog,
                        metricKey: definition.key,
                        value: value
                    )
                )
            } catch {
                invalid.insert(definition.key)
            }
        }
        invalidKeys = invalid
        if !invalid.isEmpty {
            presentError("metric.error.invalid")
            return
        }
        guard !drafts.isEmpty else {
            presentError("metric.error.empty")
            return
        }
        do {
            _ = try MetricRepository(context: modelContext).insertLogs(drafts)
            metricTexts = [:]
            invalidKeys = []
            errorKey = nil
            if selectedKey.isEmpty {
                selectedKey = drafts.first?.metricKey ?? selectedKey
            }
        } catch EaseDataError.futureDate {
            presentError("log.error.future")
        } catch {
            presentError("metric.error.invalid")
        }
    }

    private var historyListCard: some View {
        Group {
            if let selectedDefinition {
                EaseCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("metric.history.title")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(EasePalette.primaryText)
                        if historyDefinitions.count > 1 {
                            Picker("metric.history.title", selection: $selectedKey) {
                                ForEach(historyDefinitions, id: \.key) { definition in
                                    Text(verbatim: MetricCatalog.spec(for: definition).resolvedTitle)
                                        .tag(definition.key)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(EasePalette.primaryText)
                        } else {
                            Text(verbatim: MetricCatalog.spec(for: selectedDefinition).resolvedTitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                        }
                        if series.isEmpty {
                            Text("metric.history.empty")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                        } else {
                            ForEach(series.reversed(), id: \.id) { log in
                                HStack {
                                    Text(EaseFormatters.numericDate(log.timestamp))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(EasePalette.secondaryText)
                                    Spacer()
                                    Text(MetricCatalog.formattedValue(log.value, spec: MetricCatalog.spec(for: selectedDefinition)))
                                        .font(EaseFont.number(16, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundStyle(EasePalette.primaryText)
                                    EaseTextButton(title: "log.delete") {
                                        delete(log)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func delete(_ log: MetricLog) {
        try? MetricRepository(context: modelContext).delete(log)
    }

    private func presentError(_ key: String) {
        errorKey = key
        errorPulse += 1
    }
}
