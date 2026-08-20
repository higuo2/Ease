import SwiftUI
import Charts

struct MetricHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let definitions: [MetricDefinition]
    let logs: [MetricLog]
    @State private var selectedKey: String

    init(definitions: [MetricDefinition], logs: [MetricLog], initialKey: String? = nil) {
        self.definitions = definitions
        self.logs = logs
        let fallback = definitions.first?.key ?? ""
        _selectedKey = State(initialValue: initialKey ?? fallback)
    }

    private var selectedDefinition: MetricDefinition? {
        definitions.first { $0.key == selectedKey } ?? definitions.first
    }

    private var series: [MetricLog] {
        guard let selectedDefinition else { return [] }
        return logs
            .filter { $0.metricKey == selectedDefinition.key }
            .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if definitions.count > 1 {
                            EaseCard {
                                Picker("metric.history.title", selection: $selectedKey) {
                                    ForEach(definitions, id: \.key) { definition in
                                        Text(verbatim: MetricCatalog.spec(for: definition).resolvedTitle)
                                            .tag(definition.key)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(EasePalette.primaryText)
                            }
                        }
                        if let selectedDefinition {
                            EaseCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(verbatim: MetricCatalog.spec(for: selectedDefinition).resolvedTitle)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(EasePalette.secondaryText)
                                    if series.isEmpty {
                                        Text("metric.history.empty")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundStyle(EasePalette.secondaryText)
                                    } else {
                                        chart(for: selectedDefinition)
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
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("metric.history.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.accent)
    }

    private func chart(for definition: MetricDefinition) -> some View {
        let spec = MetricCatalog.spec(for: definition)
        return Chart {
            ForEach(series, id: \.id) { log in
                LineMark(
                    x: .value("chart.axis.date", log.timestamp),
                    y: .value(spec.resolvedTitle, log.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(EasePalette.primaryText.opacity(0.55))
                PointMark(
                    x: .value("chart.axis.date", log.timestamp),
                    y: .value(spec.resolvedTitle, log.value)
                )
                .foregroundStyle(EasePalette.chartMuted)
                .symbolSize(20)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 160)
    }
}
