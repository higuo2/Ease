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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                Button {
                                    onSelect(row)
                                } label: {
                                    DailyWeightRowView(row: row, style: .history)
                                }
                                .buttonStyle(.plain)
                                if index < rows.count - 1 {
                                    Divider()
                                        .overlay(EasePalette.hairline)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("weight.history.title")
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}
