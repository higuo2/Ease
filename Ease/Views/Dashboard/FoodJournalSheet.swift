import SwiftUI

struct FoodJournalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let records: [DailyRecord]

    @State private var mealPreview: MealPhotoPreviewItem?

    private var moments: [DailyRecord] {
        records
            .filter(\.hasMealPhoto)
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                if moments.isEmpty {
                    EaseEmptyState(
                        symbol: "fork.knife",
                        title: "calendar.feed.journal.empty",
                        message: "calendar.feed.journal.empty.hint"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: EaseLayout.sectionSpacing) {
                            ForEach(moments, id: \.dayKey) { record in
                                dayCard(record)
                            }
                        }
                        .padding(.horizontal, EaseLayout.screenPadding)
                        .padding(.top, 8)
                        .padding(.bottom, EaseLayout.tabBarScrollInset)
                    }
                }
            }
            .navigationTitle("calendar.feed.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .fullScreenCover(item: $mealPreview) { item in
                MealPhotoPreviewCover(fileName: item.fileName)
            }
        }
        .preferredColorScheme(.light)
    }

    private func dayCard(_ record: DailyRecord) -> some View {
        let meals = FoodJournalMeal.logged(in: record)
        return EaseCard(radius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(record.date, format: .dateTime.weekday(.wide).day().month(.abbreviated).year())
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)
                if !meals.isEmpty {
                    FoodJournalPhotoStrip(meals: meals) { fileName in
                        mealPreview = MealPhotoPreviewItem(fileName: fileName)
                    }
                }
                FoodJournalMetaBlock(record: record)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
