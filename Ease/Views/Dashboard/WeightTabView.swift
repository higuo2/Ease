import SwiftUI

struct WeightTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]
    let metricDefinitions: [MetricDefinition]
    let metricLogs: [MetricLog]

    private var selectedDate: Date { viewModel.selectedDate }
    private var snapshot: DashboardSnapshot {
        DashboardSnapshot.make(
            profile: profile,
            records: records,
            logs: logs,
            now: selectedDate
        )
    }
    private var selectedRecord: DailyRecord? {
        let key = CalendarDay.dayKey(from: selectedDate)
        return records.first { $0.dayKey == key }
    }
    private var paceLine: String? {
        guard let eta = PaceEstimator.estimate(
            samples: WeightMetrics.samples(from: records, logs: logs),
            targetWeight: snapshot.targetWeight,
            displayWeight: snapshot.displayWeight,
            progress: snapshot.progress,
            now: .now
        ) else { return nil }
        return EaseFormatters.paceETA(eta)
    }
    private var weekDelta: Double? {
        WeightMetrics.weekDelta(records: records, logs: logs, on: selectedDate)
    }
    private var waterDefinition: MetricDefinition? {
        metricDefinitions.first { $0.key == "water" }
    }
    private var waterLine: String? {
        guard let waterDefinition else { return nil }
        let key = CalendarDay.dayKey(from: selectedDate)
        let onDay = metricLogs
            .filter { $0.metricKey == "water" && CalendarDay.dayKey(from: $0.timestamp) == key }
            .sorted { $0.timestamp < $1.timestamp }
        guard let latest = onDay.last else {
            return String(localized: "shortcut.water.empty")
        }
        return MetricCatalog.formattedReading(latest.value, spec: MetricCatalog.spec(for: waterDefinition))
    }
    private var otherMetrics: [MetricDefinition] {
        metricDefinitions.filter { $0.key != "water" }
    }
    private var metricsEntry: String? {
        DashboardMetricsLine.text(enabled: otherMetrics, logs: metricLogs, on: selectedDate)
    }
    private var metricsFocusKey: String? {
        DashboardMetricsLine.focusKey(
            enabled: metricDefinitions,
            logs: metricLogs,
            on: selectedDate
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        WeightHeroView(weight: snapshot.displayWeight, weekDelta: weekDelta)
                        if snapshot.startWeight > 0, snapshot.targetWeight > 0 {
                            StageGoalCard(
                                progress: snapshot.progress,
                                startWeight: snapshot.startWeight,
                                targetWeight: snapshot.targetWeight,
                                remainingKg: snapshot.remainingKg,
                                paceLine: paceLine
                            )
                        }
                        HealthMetricGrid(
                            bmi: snapshot.bmi,
                            bodyFat: snapshot.bodyFat,
                            waterLine: waterDefinition == nil ? nil : (waterLine ?? String(localized: "shortcut.water.empty")),
                            metricsEntry: otherMetrics.isEmpty ? nil : (metricsEntry ?? String(localized: "dashboard.metrics")),
                            onOpenMetrics: {
                                viewModel.openMetrics(on: selectedDate, key: metricsFocusKey)
                            },
                            onOpenWater: {
                                viewModel.openMetrics(on: selectedDate, key: "water")
                            }
                        )
                        ShortcutCardsRow(
                            dietStatus: selectedRecord?.dietStatus,
                            waterSummary: waterLine,
                            onWater: { viewModel.openMetrics(on: selectedDate, key: "water") },
                            onDiet: viewModel.openSelectedLog
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
                EaseFAB(action: viewModel.openSelectedLog)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .navigationTitle("app.name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(EasePalette.primaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("settings.title"))
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
    }
}
