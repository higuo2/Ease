import SwiftUI
import SwiftData

struct MetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MetricDefinition.sortOrder, order: .forward) private var metricDefinitions: [MetricDefinition]
    @Query(sort: \MetricLog.timestamp, order: .forward) private var metricLogs: [MetricLog]

    @State private var selectedDate: Date
    @State private var selectedCategory: MetricInputCategory = .core
    @State private var selectedKey: String
    @State private var metricTexts: [String: String] = [:]
    @State private var invalidKeys: Set<String> = []
    @State private var errorKey: String?
    @State private var errorPulse = 0
    @State private var deletePulse = 0
    @FocusState private var focusedMetricKey: String?

    init(date: Date, initialKey: String? = nil) {
        _selectedDate = State(initialValue: CalendarDay.startOfDay(date))
        _selectedKey = State(initialValue: initialKey ?? "")
        if let initialKey {
            _selectedCategory = State(
                initialValue: MetricInputCategory.category(for: initialKey, kind: .builtin)
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background
                    .ignoresSafeArea()
                    .onTapGesture { resignInputFocus() }
                List {
                    Section {
                        dateRow
                        if availableCategories.count > 1 {
                            Picker("metric.category.title", selection: $selectedCategory) {
                                ForEach(availableCategories) { category in
                                    Text(LocalizedStringKey(category.titleKey)).tag(category)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listRowBackground(EasePalette.card)

                    if enabledMetrics.isEmpty {
                        Section {
                            Text("metric.sheet.empty")
                                .font(.subheadline)
                                .foregroundStyle(EasePalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowBackground(EasePalette.card)
                    } else {
                        Section {
                            ForEach(visibleMetrics, id: \.key) { definition in
                                MeasurementInputRow(
                                    definition: definition,
                                    text: binding(for: definition.key),
                                    isInvalid: invalidKeys.contains(definition.key),
                                    focusedMetricKey: $focusedMetricKey
                                )
                            }
                            if let errorKey {
                                Text(LocalizedStringKey(errorKey))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(EasePalette.primaryText)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listRowBackground(EasePalette.card)
                        .animation(.snappy(duration: 0.25), value: selectedCategory)
                    }

                    if selectedDefinition != nil {
                        historySection
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("metric.sheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseCloseToolbarButton(action: closeSheet)
                }
                if !enabledMetrics.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        EaseToolbarSaveButton(isEnabled: canSave, action: save)
                    }
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .onAppear(perform: alignSelection)
            .onChange(of: selectedDate) { _, _ in
                metricTexts = [:]
                invalidKeys = []
                errorKey = nil
            }
            .onChange(of: availableCategoryID) { _, _ in
                if !availableCategories.contains(selectedCategory),
                   let first = availableCategories.first {
                    selectedCategory = first
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                if !historyDefinitions.contains(where: { $0.key == selectedKey }) {
                    selectedKey = visibleMetrics.first?.key
                        ?? historyDefinitions.first?.key
                        ?? selectedKey
                }
            }
            .sensoryFeedback(.error, trigger: errorPulse)
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.7), trigger: deletePulse)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.accent)
    }

    private var availableCategoryID: String {
        availableCategories.map(\.rawValue).joined(separator: ",")
    }

    private var enabledMetrics: [MetricDefinition] {
        metricDefinitions.filter { $0.isEnabled && MetricCatalog.isActiveMetricKey($0.key) }
    }

    private var availableCategories: [MetricInputCategory] {
        MetricInputCategory.allCases.filter { category in
            enabledMetrics.contains { category.matches(key: $0.key, kind: $0.kind) }
        }
    }

    private var visibleMetrics: [MetricDefinition] {
        enabledMetrics.filter { selectedCategory.matches(key: $0.key, kind: $0.kind) }
    }

    private var historyDefinitions: [MetricDefinition] {
        var seen = Set<String>()
        var result: [MetricDefinition] = []
        let extras = metricDefinitions.filter {
            $0.key == selectedKey && MetricCatalog.isActiveMetricKey($0.key)
        }
        for definition in enabledMetrics + extras where seen.insert(definition.key).inserted {
            result.append(definition)
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
        enabledMetrics.contains {
            EaseFormatters.parseUnrounded(metricTexts[$0.key] ?? "") != nil
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
                .font(.body)
                .foregroundStyle(EasePalette.primaryText)
            Spacer(minLength: 12)
            Text(EaseFormatters.numericDate(selectedDate))
                .font(.body.monospacedDigit())
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
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var historySection: some View {
        if let selectedDefinition {
            let spec = MetricCatalog.spec(for: selectedDefinition)
            Section {
                if historyDefinitions.count > 1 {
                    historyChipBar
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if series.isEmpty {
                    Text("metric.history.empty")
                        .font(.subheadline)
                        .foregroundStyle(EasePalette.secondaryText)
                        .listRowBackground(EasePalette.card)
                } else {
                    ForEach(Array(series.enumerated()).reversed(), id: \.element.id) { index, log in
                        let previous = index > 0 ? series[index - 1].value : nil
                        let delta = previous.map {
                            MeasurementBounds.roundedToStep(log.value - $0, step: spec.step)
                        }
                        MeasurementHistoryRow(
                            date: log.timestamp,
                            valueText: readingValueText(log.value, spec: spec),
                            delta: delta,
                            deltaText: delta.flatMap {
                                abs($0) < 0.05 ? nil : MetricCatalog.formattedDelta($0, spec: spec)
                            }
                        )
                        .listRowBackground(EasePalette.card)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(log)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel(Text("log.delete"))
                        }
                    }
                }
            } header: {
                Text("metric.history.title")
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)
                    .textCase(nil)
            }
        }
    }

    private var historyChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(historyDefinitions, id: \.key) { definition in
                    let title = MetricCatalog.spec(for: definition).resolvedTitle
                    let selected = definition.key == selectedKey
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedKey = definition.key
                        }
                    } label: {
                        Text(verbatim: title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selected ? Color.white : EasePalette.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                selected ? EasePalette.morandiRedDeep : EasePalette.recessed,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { metricTexts[key] ?? "" },
            set: {
                metricTexts[key] = $0
                invalidKeys.remove(key)
            }
        )
    }

    private func readingValueText(_ value: Double, spec: MetricSpec) -> String {
        let number = MetricCatalog.formattedValue(value, spec: spec)
        let unit = String(localized: String.LocalizationValue(spec.unit.titleKey))
        return "\(number) \(unit)"
    }

    private func alignSelection() {
        if !availableCategories.contains(selectedCategory), let first = availableCategories.first {
            selectedCategory = first
        }
        if selectedKey.isEmpty || !historyDefinitions.contains(where: { $0.key == selectedKey }) {
            selectedKey = visibleMetrics.first?.key ?? historyDefinitions.first?.key ?? ""
        }
        if let selected = historyDefinitions.first(where: { $0.key == selectedKey }) {
            selectedCategory = MetricInputCategory.category(for: selected.key, kind: selected.kind)
        }
    }

    private func resignInputFocus() {
        focusedMetricKey = nil
        EaseKeyboard.dismiss()
    }

    private func closeSheet() {
        resignInputFocus()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            dismiss()
        }
    }

    private func save() {
        resignInputFocus()
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
            if let firstInvalid = enabledMetrics.first(where: { invalid.contains($0.key) }) {
                selectedCategory = MetricInputCategory.category(
                    for: firstInvalid.key,
                    kind: firstInvalid.kind
                )
            }
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

    private func delete(_ log: MetricLog) {
        deletePulse += 1
        try? MetricRepository(context: modelContext).delete(log)
    }

    private func presentError(_ key: String) {
        errorKey = key
        errorPulse += 1
    }
}

private struct MeasurementInputRow: View {
    let definition: MetricDefinition
    @Binding var text: String
    var isInvalid: Bool
    @FocusState.Binding var focusedMetricKey: String?

    private var spec: MetricSpec { MetricCatalog.spec(for: definition) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: spec.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(EasePalette.secondaryText)
                .frame(width: 28, height: 28)
                .background(
                    EasePalette.recessed,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .accessibilityHidden(true)

            Text(verbatim: spec.resolvedTitle)
                .font(.body.weight(.medium))
                .foregroundStyle(EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                TextField("0", text: $text)
                    .focused($focusedMetricKey, equals: definition.key)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(EasePalette.primaryText)
                    .frame(minWidth: 56, maxWidth: 88)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        EasePalette.recessed,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isInvalid ? EasePalette.coral : Color.clear,
                                lineWidth: 1.5
                            )
                    }
                Text(LocalizedStringKey(spec.unit.titleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: spec.resolvedTitle))
        .accessibilityValue(
            Text(
                text.isEmpty
                    ? "—"
                    : "\(text) \(String(localized: String.LocalizationValue(spec.unit.titleKey)))"
            )
        )
    }
}

private struct MeasurementHistoryRow: View {
    let date: Date
    let valueText: String
    let delta: Double?
    let deltaText: String?

    var body: some View {
        HStack(spacing: 12) {
            Text(EaseFormatters.numericDate(date))
                .font(.subheadline)
                .foregroundStyle(EasePalette.secondaryText)
                .monospacedDigit()
            Spacer(minLength: 8)
            if let delta, let deltaText, abs(delta) >= 0.05 {
                let color = EasePalette.semanticDelta(delta)
                Text(deltaText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.14), in: Capsule())
            }
            Text(valueText)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(EasePalette.primaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
