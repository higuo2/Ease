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
    private var circumferenceMetrics: [MetricDefinition] {
        metricDefinitions.filter { MetricCatalog.isActiveMetricKey($0.key) }
    }
    private var metricsFocusKey: String? {
        DashboardMetricsLine.focusKey(
            enabled: circumferenceMetrics,
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
                        HomeModuleGrid(
                            bmi: snapshot.bmi,
                            bodyFat: snapshot.bodyFat,
                            dietStatus: selectedRecord?.dietStatus,
                            onOpenMetrics: {
                                viewModel.openMetrics(on: selectedDate, key: metricsFocusKey)
                            },
                            onOpenWeight: {
                                viewModel.openWeightEntry(for: selectedDate)
                            },
                            onOpenDiet: {
                                viewModel.openDietEntry(for: selectedDate)
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
                EaseFAB(action: { viewModel.openWeightEntry(for: selectedDate) })
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
