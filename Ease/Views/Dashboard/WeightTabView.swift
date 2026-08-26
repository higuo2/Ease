import SwiftUI

struct WeightTabView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]
    let metricDefinitions: [MetricDefinition]
    let metricLogs: [MetricLog]
    @State private var isModuleEditorPresented = false
    @State private var isWeightHistoryPresented = false

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
    private var selectedHealth: HealthDaySnapshot? {
        viewModel.healthByDay[CalendarDay.dayKey(from: selectedDate)]
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
    private var homeModules: [HomeModule] {
        profile?.homeModules ?? HomeModule.defaults
    }
    private var unusedModules: [HomeModule] {
        HomeModule.allCases.filter { !homeModules.contains($0) }
    }
    private var weightRows: [DailyWeightRow] {
        DailyWeightRow.build(records: records, logs: logs)
    }

    var body: some View {
        NavigationStack {
            ZStack {
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
                            modules: homeModules,
                            bmi: snapshot.bmi,
                            bmiCategoryKey: snapshot.bmiVerdict.titleKey,
                            dietStatus: selectedRecord?.dietStatus,
                            sleepHours: selectedHealth?.previousNightSleepHours,
                            isPeriodDay: selectedHealth?.isMenstrual == true
                                || selectedRecord?.variableTags.contains(.period) == true,
                            energyKcal: selectedHealth?.activeEnergyKcal,
                            canAddMore: !unusedModules.isEmpty,
                            onOpenMetrics: {
                                viewModel.openMetrics(on: selectedDate, key: metricsFocusKey)
                            },
                            onOpenWeight: {
                                viewModel.openWeightEntry(for: selectedDate)
                            },
                            onOpenDiet: {
                                viewModel.openDietEntry(for: selectedDate)
                            },
                            onOpenSleep: { viewModel.isSleepPresented = true },
                            onOpenPeriod: { viewModel.isCyclePresented = true },
                            onOpenEnergy: { viewModel.isEnergyPresented = true },
                            onOpenBMI: { viewModel.isBMIPresented = true },
                            onAddModule: { isModuleEditorPresented = true }
                        )
                        DailyWeightList(
                            rows: weightRows,
                            onSelect: { row in
                                openWeightRow(row)
                            },
                            onDelete: { row in
                                deleteWeightRow(row)
                            },
                            onShowAll: { isWeightHistoryPresented = true }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("app.name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .sheet(isPresented: $isWeightHistoryPresented) {
                WeightHistorySheet(
                    rows: weightRows,
                    onSelect: { row in
                        isWeightHistoryPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            openWeightRow(row)
                        }
                    },
                    onDelete: { row in
                        deleteWeightRow(row)
                    },
                    onEmptyAction: {
                        isWeightHistoryPresented = false
                        viewModel.openWeightEntry(for: .now)
                    }
                )
            }
            .sheet(isPresented: $isModuleEditorPresented) {
                if let profile {
                    NavigationStack {
                        ZStack {
                            EasePalette.background.ignoresSafeArea()
                            ScrollView {
                                EaseCard {
                                    HomeModuleEditor(modules: Binding(
                                        get: { profile.homeModules },
                                        set: { newValue in
                                            profile.homeModules = newValue
                                            profile.updatedAt = .now
                                            try? modelContext.save()
                                        }
                                    ))
                                }
                                .padding(20)
                            }
                        }
                        .navigationTitle("settings.homeModules")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                EaseTextButton(title: "common.close") {
                                    isModuleEditorPresented = false
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .preferredColorScheme(.light)
                }
            }
        }
    }

    private func openWeightRow(_ row: DailyWeightRow) {
        if let id = row.latestLogID, let log = logs.first(where: { $0.id == id }) {
            viewModel.openWeightLog(log)
        } else {
            viewModel.openWeightEntry(for: row.day)
        }
    }

    private func deleteWeightRow(_ row: DailyWeightRow) {
        guard let id = row.latestLogID, let log = logs.first(where: { $0.id == id }) else { return }
        try? WeightLogRepository(context: modelContext).delete(log)
    }
}
