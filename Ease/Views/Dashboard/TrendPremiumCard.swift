import SwiftUI
import UIKit

// MARK: - Premium card shell

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

// MARK: - Tappable row chrome

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
