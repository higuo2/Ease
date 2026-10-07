import SwiftUI
import SwiftData
import Charts

struct EnergyDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let history: EnergyHistory
    let focusDate: Date
    let focusKcal: Double?
    let workoutLogs: [WorkoutLog]
    var isPlaceholder = false
    var insight: HealthInsight?

    @State private var isWorkoutSheetPresented = false
    @State private var editingWorkoutID: UUID?

    private var loggedDays: [EnergyDay] { history.loggedDays }
    private var dayWorkouts: [WorkoutLog] {
        workoutLogs
            .filter { Calendar.current.isDate($0.timestamp, inSameDayAs: focusDate) }
            .sorted { $0.timestamp < $1.timestamp }
    }
    private var chartDays: [EnergyDay] { Array(loggedDays.suffix(HealthDetailChart.chartPointLimit)) }
    private var latestChartDate: Date { chartDays.last?.date ?? history.endingOn }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("health.energy")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                if let focusKcal {
                                    Text(EaseFormatters.kcal(focusKcal))
                                        .font(EaseFont.number(32))
                                        .monospacedDigit()
                                        .foregroundStyle(EasePalette.primaryText)
                                } else {
                                    Text("module.noData")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(EasePalette.secondaryText)
                                }
                                if let average = history.averageKcal {
                                    Text(String(format: String(localized: "energy.average"), locale: .current, Int(average)))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(EasePalette.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !chartDays.isEmpty {
                            EaseCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("energy.chart.title")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(EasePalette.primaryText)
                                    Chart {
                                        ForEach(chartDays) { day in
                                            BarMark(
                                                x: .value("chart.axis.date", day.date, unit: .day),
                                                y: .value("chart.axis.energy", day.kcal ?? 0),
                                                width: .ratio(HealthDetailChart.barRatio)
                                            )
                                            .foregroundStyle(EasePalette.morandiEnergy)
                                            .cornerRadius(HealthDetailChart.barCornerRadius)
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
                                            AxisGridLine().foregroundStyle(EasePalette.track)
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(date, format: .dateTime.month(.defaultDigits).day())
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(EasePalette.secondaryText)
                                                }
                                            }
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                            AxisGridLine().foregroundStyle(EasePalette.track)
                                            AxisValueLabel {
                                                if let number = value.as(Double.self) {
                                                    Text("\(Int(number.rounded()))")
                                                        .font(.system(size: 10).monospacedDigit())
                                                        .foregroundStyle(EasePalette.secondaryText)
                                                }
                                            }
                                        }
                                    }
                                    .easeScrollableHealthChart(
                                        latestDate: latestChartDate,
                                        visibleDays: HealthDetailChart.dayBarVisibleDays
                                    )
                                    .frame(height: 180)

                                    VStack(spacing: 8) {
                                        ForEach(Array(chartDays.reversed())) { day in
                                            HealthHistoryRow(
                                                date: day.date,
                                                value: EaseFormatters.kcal(day.kcal ?? 0)
                                            )
                                        }
                                    }
                                }
                            }
                        } else {
                            EaseCard {
                                Text("energy.empty")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        workoutSection

                        if let insight {
                            HealthInsightNoteCard(insight: insight)
                        }
                    }
                    .padding(20)
                }
                .easeHealthPlaceholder(isPlaceholder)
            }
            .navigationTitle("health.energy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .sheet(isPresented: $isWorkoutSheetPresented) {
                WorkoutLogSheet(date: focusDate, editingLogID: editingWorkoutID)
                    .easeSheetPresentation()
                    .onDisappear { editingWorkoutID = nil }
            }
        }
        .preferredColorScheme(.light)
    }

    private var workoutSection: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("workout.section")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)
                Text("workout.caption")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if dayWorkouts.isEmpty {
                    Text("workout.empty")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(dayWorkouts, id: \.id) { log in
                            workoutRow(log)
                        }
                    }
                }

                Button {
                    editingWorkoutID = nil
                    isWorkoutSheetPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("workout.add")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(EasePalette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        EasePalette.recessed,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("workout.add"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func workoutRow(_ log: WorkoutLog) -> some View {
        HStack(spacing: 10) {
            Button {
                editingWorkoutID = log.id
                isWorkoutSheetPresented = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(EaseFormatters.kcal(log.kcal))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(EasePalette.primaryText)
                    if let minutes = log.durationMinutes {
                        Text("·")
                            .foregroundStyle(EasePalette.secondaryText)
                        Text(EaseFormatters.minutes(minutes))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button {
                try? WorkoutLogRepository(context: modelContext).delete(log)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EasePalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("log.delete"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(EasePalette.recessed, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
