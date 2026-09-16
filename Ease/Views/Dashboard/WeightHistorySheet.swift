import SwiftUI

struct WeightHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [WeightLogEntry]
    let onSelect: (WeightLogEntry) -> Void
    var onDelete: ((WeightLogEntry) -> Void)? = nil
    var onEmptyAction: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                if entries.isEmpty {
                    EaseEmptyState(
                        symbol: "scalemass",
                        title: "empty.history.title",
                        message: "empty.history.message",
                        action: onEmptyAction
                    )
                } else {
                    List {
                        WeightLogRows(
                            entries: entries,
                            onSelect: onSelect,
                            onDelete: onDelete
                        )
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .easeTabListMargins()
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
