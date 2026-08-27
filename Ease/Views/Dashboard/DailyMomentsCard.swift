import SwiftUI

struct DailyMomentsCard: View {
    let date: Date
    let record: DailyRecord?
    let onAddMeal: () -> Void

    @State private var mealPreview: MealPhotoPreviewItem?

    private var loggedMeals: [(slot: MealSlot, fileName: String)] {
        guard let record else { return [] }
        return record.visibleMealSlots.compactMap { slot in
            guard let fileName = record.mealPhotoFileName(for: slot) else { return nil }
            return (slot, fileName)
        }
    }

    private var note: String? {
        record?.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var hasJournal: Bool {
        record?.dietStatus != nil
            || !(record?.variableTags.isEmpty ?? true)
            || note != nil
            || !loggedMeals.isEmpty
    }

    private var mealColumns: [GridItem] {
        let count = max(loggedMeals.count, 1)
        let columns = min(2, count)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
    }

    var body: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if hasJournal {
                    if !loggedMeals.isEmpty {
                        mealGrid
                    }
                    badges
                    if let note {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fullScreenCover(item: $mealPreview) { item in
            MealPhotoPreviewCover(fileName: item.fileName)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("calendar.feed.title")
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)
                Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if hasJournal {
                Button(action: onAddMeal) {
                    Text("calendar.feed.edit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EasePalette.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mealGrid: some View {
        LazyVGrid(columns: mealColumns, spacing: 10) {
            ForEach(loggedMeals, id: \.slot.id) { item in
                Button {
                    mealPreview = MealPhotoPreviewItem(fileName: item.fileName)
                } label: {
                    VStack(spacing: 6) {
                        MealPhotoThumbnail(
                            fileName: item.fileName,
                            cornerRadius: 12
                        )
                        Text(verbatim: item.slot.displayTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(EasePalette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: item.slot.displayTitle))
                .accessibilityHint(Text("calendar.meal.preview"))
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        let tags = record?.variableTags ?? []
        if record?.dietStatus != nil || !tags.isEmpty {
            EaseFlowLayout(spacing: 8) {
                if let diet = record?.dietStatus {
                    dietBadge(diet)
                }
                ForEach(tags) { tag in
                    tagBadge(tag)
                }
            }
        }
    }

    private func dietBadge(_ status: DietStatus) -> some View {
        let tint = EasePalette.dietTint(status)
        return HStack(spacing: 5) {
            Image(systemName: status.systemImage)
            Text(LocalizedStringKey(status.titleKey))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.16), in: Capsule())
    }

    private func tagBadge(_ tag: VariableTag) -> some View {
        HStack(spacing: 5) {
            Image(systemName: tag.systemImage)
            tag.titleText
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(EasePalette.secondaryText)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(EasePalette.recessed, in: Capsule())
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("calendar.feed.empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onAddMeal) {
                Text("calendar.feed.add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EasePalette.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
