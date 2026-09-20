import SwiftUI
import UIKit

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

// MARK: - Premium Trend cards (compiled with TrendAnalysisChrome for target membership)

struct TrendPremiumCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
    }
}

struct TrendActionRow<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                tint.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

struct TrendInsightAccentIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(
                tint.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

enum TrendInsightStyle {
    static func rowTint(for kind: HealthInsight.Kind) -> Color {
        switch kind {
        case .shortSleepWeight, .weekdaySleep:
            return .indigo
        case .periodWeight:
            return EasePalette.iconPeriod
        case .lowEnergyWeight:
            return EasePalette.iconEnergy
        }
    }

    static func deltaColor(for insight: HealthInsight) -> Color {
        if insight.comparesWeight {
            return EasePalette.semanticDelta(insight.delta)
        }
        if insight.delta < -0.05 {
            return Color.orange
        }
        if insight.delta > 0.05 {
            return EasePalette.mint
        }
        return EasePalette.primaryText
    }
}
