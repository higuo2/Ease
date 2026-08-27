import SwiftUI
import SwiftData
import UIKit

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.date, order: .forward) private var records: [DailyRecord]
    @Query(sort: \WeightLog.timestamp, order: .forward) private var weightLogs: [WeightLog]
    @Query(sort: \MetricDefinition.sortOrder, order: .forward) private var metricDefinitions: [MetricDefinition]
    @Query(sort: \MetricLog.timestamp, order: .forward) private var metricLogs: [MetricLog]
    @State private var viewModel = DashboardViewModel()
    @State private var selectedTab: AppTab = .weight

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
                editingLogID: viewModel.editingLogID,
                mode: viewModel.logMode
            )
            .easeSheetPresentation()
        }
        .sheet(isPresented: $viewModel.isSleepPresented) {
            SleepSheetHost(viewModel: viewModel, profile: profile)
        }
        .sheet(isPresented: $viewModel.isCyclePresented) {
            CycleDetailSheet(
                history: viewModel.cycleHistory,
                isPlaceholder: !viewModel.hasLoadedHealth
            )
            .easeSheetPresentation()
        }
        .sheet(isPresented: $viewModel.isEnergyPresented) {
            EnergySheetHost(viewModel: viewModel)
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
            dietHour: profile?.dietReminderHour ?? NotificationSchedulePolicy.dietHour,
            dietMinute: profile?.dietReminderMinute ?? NotificationSchedulePolicy.dietMinute,
            forceHealth: forceHealth
        )
    }

    private func refreshNotifications() async {
        await viewModel.refreshNotifications(
            enabled: profile?.notificationsEnabled == true,
            records: records,
            logs: weightLogs,
            weightHour: profile?.weightReminderHour ?? NotificationSchedulePolicy.weightHour,
            weightMinute: profile?.weightReminderMinute ?? NotificationSchedulePolicy.weightMinute,
            dietHour: profile?.dietReminderHour ?? NotificationSchedulePolicy.dietHour,
            dietMinute: profile?.dietReminderMinute ?? NotificationSchedulePolicy.dietMinute
        )
    }
}

private struct SleepSheetHost: View {
    @Bindable var viewModel: DashboardViewModel
    let profile: UserProfile?

    var body: some View {
        SleepDetailSheet(
            history: viewModel.sleepHistory,
            focusHours: viewModel.healthByDay[CalendarDay.dayKey(from: viewModel.selectedDate)]?.previousNightSleepHours,
            targetHours: profile?.sleepTargetHours ?? 8.0,
            isPlaceholder: !viewModel.hasLoadedHealth
        )
        .easeSheetPresentation()
    }
}

private struct EnergySheetHost: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        EnergyDetailSheet(
            history: viewModel.energyHistory,
            focusKcal: viewModel.healthByDay[CalendarDay.dayKey(from: viewModel.selectedDate)]?.activeEnergyKcal,
            isPlaceholder: !viewModel.hasLoadedHealth
        )
        .easeSheetPresentation()
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
