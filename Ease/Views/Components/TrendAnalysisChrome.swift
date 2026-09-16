import SwiftUI

enum TrendAnalysisMotion {
    static let accordion = Animation.spring(response: 0.3, dampingFraction: 0.8)
}

struct TrendAnalysisHeader: View {
    let title: LocalizedStringKey
    let windowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EasePalette.primaryText)
            Text(windowCaption)
                .font(.subheadline)
                .foregroundStyle(EasePalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var windowCaption: String {
        String(
            format: String(localized: "trend.insights.window"),
            locale: .current,
            windowDays
        )
    }
}

struct TrendTintIconTile: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(
                tint.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

struct TrendAnalysisFootnote: View {
    var body: some View {
        Text("trend.insights.footnote")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
