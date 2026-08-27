import SwiftUI

struct DietStatusChipFlow: View {
    let selection: DietStatus?
    let onSelect: (DietStatus?) -> Void

    var body: some View {
        EaseFlowLayout(spacing: 8) {
            ForEach(DietStatus.allCases, id: \.self) { status in
                chip(status)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: selection?.rawValue ?? "none")
    }

    private func chip(_ status: DietStatus) -> some View {
        let selected = selection == status
        let tint = EasePalette.dietTint(status)
        return Button {
            onSelect(selected ? nil : status)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: status.systemImage)
                Text(LocalizedStringKey(status.titleKey))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? Color.white : EasePalette.secondaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(selected ? tint : EasePalette.recessed, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct VariableTagChipFlow: View {
    let selection: Set<VariableTag>
    let onToggle: (VariableTag) -> Void
    var onAddCustom: () -> Void
    var onRemoveCustom: ((VariableTag) -> Void)? = nil

    private var visibleTags: [VariableTag] {
        VariableTag.presets + selection.filter(\.isCustom).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        EaseFlowLayout(spacing: 8) {
            ForEach(visibleTags) { tag in
                chip(tag)
            }
            addChip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: selection.map(\.rawValue).sorted().joined())
    }

    private func chip(_ tag: VariableTag) -> some View {
        let selected = selection.contains(tag)
        return Button {
            onToggle(tag)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tag.systemImage)
                tag.titleText
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? EasePalette.accent : EasePalette.secondaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                selected ? EasePalette.accent.opacity(0.16) : EasePalette.recessed,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu {
            if tag.isCustom, let onRemoveCustom {
                Button(role: .destructive) {
                    onRemoveCustom(tag)
                } label: {
                    Label("tag.custom.remove", systemImage: "trash")
                }
            }
        }
    }

    private var addChip: some View {
        Button(action: onAddCustom) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("tag.custom.add")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(EasePalette.secondaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(EasePalette.recessed, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension VariableTag {
    var titleText: Text {
        if let titleKey {
            Text(LocalizedStringKey(titleKey))
        } else {
            Text(verbatim: customLabel)
        }
    }
}
