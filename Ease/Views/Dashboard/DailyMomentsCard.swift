import SwiftUI

struct DailyMomentsCard: View {
    let date: Date
    let record: DailyRecord?
    let journalRecords: [DailyRecord]
    let onAddMeal: () -> Void

    @State private var mealPreview: MealPhotoPreviewItem?
    @State private var isJournalPresented = false

    private var loggedMeals: [FoodJournalMeal] {
        FoodJournalMeal.logged(in: record)
    }

    private var hasJournal: Bool {
        record?.dietStatus != nil
            || !(record?.variableTags.isEmpty ?? true)
            || FoodJournalMeal.note(from: record) != nil
            || !loggedMeals.isEmpty
    }

    var body: some View {
        EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if hasJournal {
                    if !loggedMeals.isEmpty {
                        FoodJournalPhotoStrip(meals: loggedMeals) { fileName in
                            mealPreview = MealPhotoPreviewItem(fileName: fileName)
                        }
                    }
                    FoodJournalMetaBlock(record: record)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fullScreenCover(item: $mealPreview) { item in
            MealPhotoPreviewCover(fileName: item.fileName)
        }
        .sheet(isPresented: $isJournalPresented) {
            FoodJournalSheet(records: journalRecords)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
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
            Button {
                isJournalPresented = true
            } label: {
                HStack(spacing: 2) {
                    Text("calendar.feed.all")
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(EasePalette.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("calendar.feed.all"))
        }
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

struct FoodJournalMeal: Identifiable {
    var id: String { slot.id }
    let slot: MealSlot
    let fileName: String

    static func logged(in record: DailyRecord?) -> [FoodJournalMeal] {
        guard let record else { return [] }
        return record.visibleMealSlots.compactMap { slot in
            guard let fileName = record.mealPhotoFileName(for: slot) else { return nil }
            return FoodJournalMeal(slot: slot, fileName: fileName)
        }
    }

    static func note(from record: DailyRecord?) -> String? {
        record?.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

struct FoodJournalPhotoStrip: View {
    let meals: [FoodJournalMeal]
    var thumbnailSize: CGFloat = 110
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(meals) { item in
                    Button {
                        onSelect(item.fileName)
                    } label: {
                        VStack(spacing: 6) {
                            MealPhotoThumbnail(
                                fileName: item.fileName,
                                cornerRadius: 12
                            )
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            Text(verbatim: item.slot.displayTitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(EasePalette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: thumbnailSize)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: item.slot.displayTitle))
                    .accessibilityHint(Text("calendar.meal.preview"))
                }
            }
        }
    }
}

struct FoodJournalMetaBlock: View {
    let record: DailyRecord?

    var body: some View {
        let tags = record?.variableTags ?? []
        let note = FoodJournalMeal.note(from: record)
        VStack(alignment: .leading, spacing: 8) {
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
            if let note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
}

extension String {
    fileprivate var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
