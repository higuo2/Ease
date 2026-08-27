import SwiftUI

struct MealPhotoCarousel: View {
    let slots: [MealSlot]
    var fileName: (MealSlot) -> String?
    var isBusy: (MealSlot) -> Bool
    var onTap: (MealSlot) -> Void
    var onReplace: (MealSlot) -> Void
    var onClear: (MealSlot) -> Void
    var onRemoveCustom: ((MealSlot) -> Void)? = nil
    var onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(slots) { slot in
                    card(slot)
                }
                addCard
            }
        }
    }

    private func card(_ slot: MealSlot) -> some View {
        let name = fileName(slot)
        return Button {
            onTap(slot)
        } label: {
            VStack(spacing: 8) {
                MealPhotoThumbnail(
                    fileName: name,
                    isBusy: isBusy(slot)
                )
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(EasePalette.hairline, lineWidth: 0.5)
                )
                slotTitle(slot)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(EasePalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 100)
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy(slot))
        .contextMenu {
            if name != nil {
                Button {
                    onReplace(slot)
                } label: {
                    Label("calendar.meal.replace", systemImage: "photo")
                }
                Button(role: .destructive) {
                    onClear(slot)
                } label: {
                    Label("calendar.meal.remove", systemImage: "trash")
                }
            }
            if slot.isCustom, let onRemoveCustom {
                Button(role: .destructive) {
                    onRemoveCustom(slot)
                } label: {
                    Label("meal.custom.remove", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel(Text(verbatim: slot.displayTitle))
    }

    private var addCard: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(EasePalette.recessed)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            EasePalette.hairline,
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 100, height: 100)
                Text("meal.add")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(EasePalette.secondaryText)
                    .lineLimit(1)
                    .frame(width: 100)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("meal.add"))
    }

    private func slotTitle(_ slot: MealSlot) -> Text {
        if let titleKey = slot.titleKey {
            return Text(LocalizedStringKey(titleKey))
        }
        return Text(verbatim: slot.displayTitle)
    }
}
