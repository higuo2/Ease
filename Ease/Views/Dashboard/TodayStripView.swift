import SwiftUI

struct TodayStripView: View {
    let record: DailyRecord?

    var body: some View {
        EaseCard {
            HStack(spacing: 16) {
                if let diet = record?.dietStatus {
                    labeledIcon(systemName: diet.systemImage, label: diet.titleKey)
                } else {
                    labeledIcon(systemName: "circle.dashed", label: "today.dietPending")
                }
                if let record {
                    ForEach(record.variableTags, id: \.self) { tag in
                        labeledIcon(systemName: tag.systemImage, label: tag.titleKey)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func labeledIcon(systemName: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(EasePalette.primaryText)
            Text(LocalizedStringKey(label))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
        }
        .frame(minWidth: 44)
    }
}
