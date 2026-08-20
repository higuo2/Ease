import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.date, order: .forward) private var records: [DailyRecord]
    @Query(sort: \WeightLog.timestamp, order: .forward) private var weightLogs: [WeightLog]
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
                            targetWeight: snapshot.targetWeight
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
                            bmi: snapshot.bmi
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
                    SettingsSheet(profile: profile, records: Array(records), logs: Array(weightLogs))
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
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await reloadHealthAndNotifications()
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
            logs: Array(weightLogs)
        )
    }
}

#Preview {
    DashboardView()
        .modelContainer(EaseModelContainer.preview())
}
