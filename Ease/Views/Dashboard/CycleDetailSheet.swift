import SwiftUI
import Charts

struct CycleDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let history: CycleHistory

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if history.progress != nil || history.predictedNextStart != nil {
                            EaseCard {
                                HStack(spacing: 20) {
                                    if let progress = history.progress {
                                        EaseArcRing(
                                            progress: progress,
                                            colors: [EasePalette.periodPink, EasePalette.periodRose],
                                            diameter: 120
                                        )
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("cycle.title")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundStyle(EasePalette.secondaryText)
                                        if let next = history.predictedNextStart {
                                            Text(EaseFormatters.cycleNext(next))
                                                .font(.system(size: 16, weight: .regular))
                                                .foregroundStyle(EasePalette.primaryText)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }

                        if !history.spans.isEmpty {
                            EaseCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    timelineChart
                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(history.spans.reversed()) { span in
                                            Text(spanLabel(span))
                                                .font(.system(size: 14, weight: .regular))
                                                .monospacedDigit()
                                                .foregroundStyle(EasePalette.primaryText)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("cycle.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.periodRose)
    }

    private var timelineChart: some View {
        Chart {
            ForEach(history.spans) { span in
                BarMark(
                    xStart: .value("chart.axis.date", span.start),
                    xEnd: .value("chart.axis.date", CalendarDay.endOfDay(span.end)),
                    y: .value("cycle.title", 1)
                )
                .foregroundStyle(EasePalette.periodRose.opacity(0.55))
                .cornerRadius(4)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 36)
    }

    private func spanLabel(_ span: CycleSpan) -> String {
        let style = Date.FormatStyle().month(.abbreviated).day()
        if Calendar.current.isDate(span.start, inSameDayAs: span.end) {
            return span.start.formatted(style)
        }
        return "\(span.start.formatted(style)) – \(span.end.formatted(style))"
    }
}
