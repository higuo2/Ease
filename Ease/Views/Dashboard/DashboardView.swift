import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.date, order: .forward) private var records: [DailyRecord]
    @State private var viewModel = DashboardViewModel()

    private var profile: UserProfile? { profiles.first }
    private var snapshot: DashboardSnapshot {
        DashboardSnapshot.make(profile: profile, records: Array(records))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        ProgressRingView(
                            progress: snapshot.progress,
                            lostKg: snapshot.lostKg,
                            remainingKg: snapshot.remainingKg,
                            targetWeight: snapshot.targetWeight
                        )
                        .padding(.top, 8)

                        TodayStripView(record: snapshot.today)
                        WeightSummaryCard(
                            weight: snapshot.displayWeight,
                            bodyFat: snapshot.bodyFat,
                            bmi: snapshot.bmi
                        )
                        TrendChartCard(
                            records: Array(records),
                            range: viewModel.chartRange,
                            onSelectRange: { viewModel.chartRange = $0 },
                            onSelectDate: { viewModel.openLog(for: $0) }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96)
                }
                EaseFAB(action: viewModel.openTodayLog)
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
                    SettingsSheet(profile: profile, records: Array(records))
                }
            }
            .sheet(isPresented: $viewModel.isLogPresented) {
                LogSheetView(date: viewModel.editingDate)
            }
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.accent)
    }
}

#Preview {
    DashboardView()
        .modelContainer(EaseModelContainer.preview())
}
