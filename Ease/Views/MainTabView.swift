import SwiftUI
import SwiftData
import UIKit

struct MainTabView: View {
    private enum QueryWindow {
        static let recordDays = 180
        static let weightLogDays = 365
        static let metricLogDays = 365
    }

    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var records: [DailyRecord]
    @Query private var weightLogs: [WeightLog]
    @Query private var metricDefinitions: [MetricDefinition]
    @Query private var metricLogs: [MetricLog]
    @State private var viewModel = DashboardViewModel()
    @State private var selectedTab: AppTab = .weight

    init() {
        let now = CalendarDay.startOfDay(.now)
        let recordsCutoff = CalendarDay.addingDays(-QueryWindow.recordDays, to: now)
        let weightLogsCutoff = CalendarDay.addingDays(-QueryWindow.weightLogDays, to: now)
        let metricLogsCutoff = CalendarDay.addingDays(-QueryWindow.metricLogDays, to: now)

        _profiles = Query(sort: \UserProfile.updatedAt, order: .reverse)
        _records = Query(
            filter: #Predicate<DailyRecord> { $0.date >= recordsCutoff },
            sort: \DailyRecord.date,
            order: .forward
        )
        _weightLogs = Query(
            filter: #Predicate<WeightLog> { $0.timestamp >= weightLogsCutoff },
            sort: \WeightLog.timestamp,
            order: .forward
        )
        _metricDefinitions = Query(
            filter: #Predicate<MetricDefinition> { $0.isEnabled },
            sort: \MetricDefinition.sortOrder,
            order: .forward
        )
        _metricLogs = Query(
            filter: #Predicate<MetricLog> { $0.timestamp >= metricLogsCutoff },
            sort: \MetricLog.timestamp,
            order: .forward
        )
    }

    private var profile: UserProfile? { profiles.first }
    private var enabledMetrics: [MetricDefinition] {
        metricDefinitions.filter { $0.isEnabled && MetricCatalog.isActiveMetricKey($0.key) }
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        TabView(selection: $selectedTab) {
            WeightTabView(
                viewModel: viewModel,
                profile: profile,
                records: records,
                logs: weightLogs,
                metricDefinitions: enabledMetrics,
                metricLogs: metricLogs
            )
            .tabItem { Label("tab.weight", systemImage: "scalemass") }
            .tag(AppTab.weight)

            TrendTabView(
                viewModel: viewModel,
                profile: profile,
                records: records,
                logs: weightLogs
            )
            .tabItem { Label("tab.trend", systemImage: "chart.xyaxis.line") }
            .tag(AppTab.trend)

            CalendarTabView(
                viewModel: viewModel,
                records: records,
                logs: weightLogs
            )
            .tabItem { Label("tab.calendar", systemImage: "calendar") }
            .tag(AppTab.calendar)

            if let profile {
                SettingsSheet(
                    profile: profile,
                    records: records,
                    logs: weightLogs
                )
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
            }
        }
        .tint(EasePalette.primaryText)
        .preferredColorScheme(.light)
        .sheet(isPresented: $viewModel.isLogPresented) {
            LogSheetView(
                date: viewModel.editingDate,
                editingLogID: viewModel.editingLogID
            )
            .easeSheetPresentation()
        }
        .sheet(isPresented: $viewModel.isSleepPresented) {
            SleepSheetHost(
                viewModel: viewModel,
                profile: profile,
                records: records,
                logs: weightLogs
            )
        }
        .sheet(isPresented: $viewModel.isCyclePresented) {
            CycleDetailSheet(
                history: viewModel.cycleHistory,
                isPlaceholder: !viewModel.hasLoadedHealth
            )
            .easeSheetPresentation()
        }
        .sheet(isPresented: $viewModel.isEnergyPresented) {
            EnergySheetHost(
                viewModel: viewModel,
                records: records,
                logs: weightLogs
            )
        }
        .sheet(isPresented: $viewModel.isBMIPresented) {
            BMISheetHost(
                viewModel: viewModel,
                profile: profile,
                records: records,
                logs: weightLogs
            )
        }
        .sheet(isPresented: $viewModel.isMetricSheetPresented) {
            MetricSheet(date: viewModel.metricsDate, initialKey: viewModel.metricFocusKey)
                .easeSheetPresentation()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await reloadHealthAndNotifications(forceHealth: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await reloadHealthAndNotifications(forceHealth: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await reloadHealthAndNotifications(forceHealth: true) }
        }
        .onChange(of: viewModel.isLogPresented) { _, presented in
            if !presented {
                viewModel.editingLogID = nil
                Task { await refreshNotifications() }
            }
        }
    }

    private func reloadHealthAndNotifications(forceHealth: Bool) async {
        await viewModel.reloadHealthAndNotifications(
            enabled: profile?.notificationsEnabled == true,
            records: records,
            logs: weightLogs,
            weightHour: profile?.weightReminderHour ?? NotificationSchedulePolicy.weightHour,
            weightMinute: profile?.weightReminderMinute ?? NotificationSchedulePolicy.weightMinute,
            forceHealth: forceHealth
        )
    }

    private func refreshNotifications() async {
        await viewModel.refreshNotifications(
            enabled: profile?.notificationsEnabled == true,
            records: records,
            logs: weightLogs,
            weightHour: profile?.weightReminderHour ?? NotificationSchedulePolicy.weightHour,
            weightMinute: profile?.weightReminderMinute ?? NotificationSchedulePolicy.weightMinute
        )
    }
}

private struct SleepSheetHost: View {
    @Bindable var viewModel: DashboardViewModel
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]

    var body: some View {
        SleepDetailSheet(
            history: viewModel.sleepHistory,
            focusHours: viewModel.healthByDay[CalendarDay.dayKey(from: viewModel.selectedDate)]?.previousNightSleepHours,
            targetHours: profile?.sleepTargetHours ?? 8.0,
            isPlaceholder: !viewModel.hasLoadedHealth,
            insight: insightReport.sleepNote
        )
        .easeSheetPresentation()
    }

    private var insightReport: HealthInsightReport {
        HealthInsightEngine.report(
            records: records,
            logs: logs,
            healthByDay: viewModel.healthByDay,
            sleepHistory: viewModel.sleepHistory,
            energyHistory: viewModel.energyHistory,
            cycleHistory: viewModel.cycleHistory
        )
    }
}

private struct EnergySheetHost: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    var body: some View {
        EnergyDetailSheet(
            history: viewModel.energyHistory,
            focusKcal: viewModel.healthByDay[CalendarDay.dayKey(from: viewModel.selectedDate)]?.activeEnergyKcal,
            isPlaceholder: !viewModel.hasLoadedHealth,
            insight: insightReport.energyNote
        )
        .easeSheetPresentation()
    }

    private var insightReport: HealthInsightReport {
        HealthInsightEngine.report(
            records: records,
            logs: logs,
            healthByDay: viewModel.healthByDay,
            sleepHistory: viewModel.sleepHistory,
            energyHistory: viewModel.energyHistory,
            cycleHistory: viewModel.cycleHistory
        )
    }
}

private struct BMISheetHost: View {
    @Bindable var viewModel: DashboardViewModel
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]

    var body: some View {
        let snapshot = DashboardSnapshot.make(
            profile: profile,
            records: records,
            logs: logs,
            now: viewModel.selectedDate
        )
        BMIDetailSheet(
            bmi: snapshot.bmi,
            weightKg: snapshot.displayWeight,
            heightCm: profile?.heightCm ?? 0,
            birthDate: profile?.birthDate,
            sex: profile?.sex ?? .unspecified,
            now: viewModel.selectedDate
        )
        .easeSheetPresentation()
    }
}

private enum AppTab: Hashable {
    case weight, trend, calendar, settings
}

#Preview {
    MainTabView()
        .modelContainer(EaseModelContainer.preview())
        .environment(MealCutoutPreferences.shared)
}
