import SwiftUI

/// Centered empty-data layout: symbol, wrapping copy, and a primary CTA.
struct EaseEmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey = "empty.cta"
    var actionHint: LocalizedStringKey? = "empty.cta.hint"
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 48, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(EasePalette.secondaryText)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.body)
                    .foregroundStyle(EasePalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if let action {
                EasePrimaryButton(
                    title: actionTitle,
                    accessibilityHint: actionHint,
                    action: action
                )
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Long-press menu for a logged row: Edit + destructive Delete, with haptics.
struct EaseRecordContextMenu: ViewModifier {
    let onEdit: () -> Void
    var onDelete: (() -> Void)?
    @State private var menuTick = 0
    @State private var deleteTick = 0

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button(action: onEdit) {
                    Label("common.edit", systemImage: "pencil")
                }
                if let onDelete {
                    Button(role: .destructive) {
                        deleteTick += 1
                        onDelete()
                    } label: {
                        Label("log.delete", systemImage: "trash")
                    }
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    menuTick += 1
                }
            )
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.85), trigger: menuTick)
            .sensoryFeedback(.warning, trigger: deleteTick)
    }
}

extension View {
    func easeRecordContextMenu(
        onEdit: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        modifier(EaseRecordContextMenu(onEdit: onEdit, onDelete: onDelete))
    }
}
