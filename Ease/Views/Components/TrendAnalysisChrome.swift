import SwiftUI

enum TrendAnalysisMotion {
    static let accordion = Animation.spring(duration: 0.25)
}

struct TrendAnalysisHeader: View {
    let title: LocalizedStringKey
    let windowDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EasePalette.primaryText)
            Text(windowCaption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
    var soft: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(soft ? tint.opacity(0.78) : tint)
            .frame(width: 28, height: 28)
            .background(
                tint.opacity(soft ? 0.08 : 0.12),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

struct TrendAnalysisFootnote: View {
    var body: some View {
        TrendLegalFootnote("trend.insights.footnote")
    }
}

struct TrendLegalFootnote: View {
    let key: LocalizedStringKey

    init(_ key: LocalizedStringKey) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }
}

struct TrendEntryChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
