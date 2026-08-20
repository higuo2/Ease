import SwiftUI
import SwiftData
import UIKit

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.date, order: .forward) private var records: [DailyRecord]
    @Query(sort: \WeightLog.timestamp, order: .forward) private var weightLogs: [WeightLog]
    @Query(sort: \MetricDefinition.sortOrder, order: .forward) private var metricDefinitions: [MetricDefinition]
    @Query(sort: \MetricLog.timestamp, order: .forward) private var metricLogs: [MetricLog]
    @State private var viewModel = DashboardViewModel()

    private var profile: UserProfile? { profiles.first }
    private var selectedDate: Date { viewModel.selectedDate }
    private var snapshot: DashboardSnapshot {
        DashboardSnapshot.make(
            profile: profile,
            records: Array(records),
            logs: Array(weightLogs),
            now: selectedDate
        )
    }
    private var selectedRecord: DailyRecord? {
        let key = CalendarDay.dayKey(from: selectedDate)
        return records.first { $0.dayKey == key }
    }
    private var selectedHealth: HealthDaySnapshot? {
        viewModel.healthByDay[CalendarDay.dayKey(from: selectedDate)]
    }
    private var paceLine: String? {
        guard let eta = PaceEstimator.estimate(
            samples: WeightMetrics.samples(from: Array(records), logs: Array(weightLogs)),
            targetWeight: snapshot.targetWeight,
            displayWeight: snapshot.displayWeight,
            progress: snapshot.progress,
            now: .now
        ) else { return nil }
        return EaseFormatters.paceETA(eta)
    }
    private var metricsLine: String? {
        let enabled = metricDefinitions.filter(\.isEnabled)
        guard !enabled.isEmpty else { return nil }
        let key = CalendarDay.dayKey(from: selectedDate)
        var parts: [String] = []
        for definition in enabled {
            let onDay = metricLogs
                .filter { $0.metricKey == definition.key && CalendarDay.dayKey(from: $0.timestamp) == key }
                .sorted { $0.timestamp < $1.timestamp }
            guard let latest = onDay.last else { continue }
            parts.append(MetricCatalog.formattedReading(latest.value, spec: MetricCatalog.spec(for: definition)))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  ")
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        DayPickerHeader(
                            selectedDate: $viewModel.selectedDate,
                            mode: $viewModel.dayPickerMode
                        )
                        ProgressRingView(
                            progress: snapshot.progress,
                            lostKg: snapshot.lostKg,
                            remainingKg: snapshot.remainingKg,
                            targetWeight: snapshot.targetWeight,
                            paceLine: paceLine
                        )
                        HealthCardsView(
                            record: selectedRecord,
                            health: selectedHealth,
                            onOpenSleep: { viewModel.isSleepPresented = true },
                            onOpenCycle: { viewModel.isCyclePresented = true }
                        )
                        WeightSummaryCard(
                            weight: snapshot.displayWeight,
                            bodyFat: snapshot.bodyFat,
                            bmi: snapshot.bmi,
                            metricsLine: metricsLine,
                            onOpenMetrics: metricsLine == nil ? nil : {
                                viewModel.metricHistoryKey = metricDefinitions.first(where: \.isEnabled)?.key
                                viewModel.isMetricHistoryPresented = true
                            }
                        )
                        TrendChartCard(
                            records: Array(records),
                            logs: Array(weightLogs),
                            healthByDay: viewModel.healthByDay,
                            range: viewModel.chartRange,
                            onSelectRange: { viewModel.chartRange = $0 },
                            onSelectLog: { viewModel.openWeightLog($0) }
                        )
                    }
                    .padding(.horizontal, 20)
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
            .sheet(isPresented: $viewModel.isSettingsPresented) {
                if let profile {
                    SettingsSheet(
                        profile: profile,
                        records: Array(records),
                        logs: Array(weightLogs)
                    )
                }
            }
            .sheet(isPresented: $viewModel.isLogPresented) {
                LogSheetView(date: viewModel.editingDate, editingLogID: viewModel.editingLogID)
            }
            .sheet(isPresented: $viewModel.isSleepPresented) {
                SleepDetailSheet(
                    history: viewModel.sleepHistory,
                    focusHours: selectedHealth?.previousNightSleepHours,
                    targetHours: profile?.sleepTargetHours ?? 8.0
                )
            }
            .sheet(isPresented: $viewModel.isCyclePresented) {
                CycleDetailSheet(history: viewModel.cycleHistory)
            }
            .sheet(isPresented: $viewModel.isMetricHistoryPresented) {
                MetricHistorySheet(
                    definitions: metricDefinitions.filter(\.isEnabled),
                    logs: Array(metricLogs),
                    initialKey: viewModel.metricHistoryKey
                )
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await reloadHealthAndNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                Task { await reloadHealthAndNotifications() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                Task { await reloadHealthAndNotifications() }
            }
            .onChange(of: viewModel.isLogPresented) { _, presented in
                if !presented {
                    viewModel.editingLogID = nil
                    Task { await reloadHealthAndNotifications() }
                }
            }
            .onChange(of: viewModel.isSettingsPresented) { _, presented in
                if !presented { Task { await reloadHealthAndNotifications() } }
            }
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.accent)
    }

    private func reloadHealthAndNotifications() async {
        await viewModel.reloadHealthAndNotifications(
            enabled: profile?.notificationsEnabled == true,
            records: Array(records),
            logs: Array(weightLogs),
            weightHour: profile?.weightReminderHour ?? NotificationSchedulePolicy.weightHour,
            weightMinute: profile?.weightReminderMinute ?? NotificationSchedulePolicy.weightMinute,
            dietHour: profile?.dietReminderHour ?? NotificationSchedulePolicy.dietHour,
            dietMinute: profile?.dietReminderMinute ?? NotificationSchedulePolicy.dietMinute
        )
    }
}

#Preview {
    DashboardView()
        .modelContainer(EaseModelContainer.preview())
}
