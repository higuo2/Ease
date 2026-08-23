import SwiftUI

struct WeightHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let rows: [DailyWeightRow]
    let onSelect: (DailyWeightRow) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                if rows.isEmpty {
                    Text("weight.list.empty")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                } else {
                    ScrollView {
                        EaseCard(padding: 4) {
                            VStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                    Button {
                                        onSelect(row)
                                    } label: {
                                        DailyWeightRowView(row: row)
                                    }
                                    .buttonStyle(.plain)
                                    if index < rows.count - 1 {
                                        Divider()
                                            .overlay(EasePalette.hairline)
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("weight.history.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}
