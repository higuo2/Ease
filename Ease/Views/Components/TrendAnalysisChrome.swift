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

struct TrendHealthIconBadge: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(
                tint.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

struct TrendHealthMetricCard<Content: View>: View {
    let action: (() -> Void)?
    var accessibilityHintKey: LocalizedStringKey? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let card = content()
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
            .overlay(shape.stroke(Color.primary.opacity(0.04), lineWidth: 1))
            .contentShape(shape)

        if let action {
            Button(action: action) { card }
                .buttonStyle(TrendCardRowButtonStyle())
                .modifier(OptionalAccessibilityHint(key: accessibilityHintKey))
        } else {
            card
        }
    }
}

enum TrendInsightStyle {
    static func badgeTint(for kind: HealthInsight.Kind) -> Color {
        switch kind {
        case .shortSleepWeight, .weekdaySleep:
            Color.indigo
        case .periodWeight:
            Color.pink
        case .lowEnergyWeight:
            Color.orange
        }
    }

    static func valueColor(for insight: HealthInsight) -> Color {
        if insight.comparesWeight {
            return EasePalette.semanticDelta(insight.delta)
        }
        return Color.orange
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

private struct OptionalAccessibilityHint: ViewModifier {
    var key: LocalizedStringKey?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let key {
            content.accessibilityHint(Text(key))
        } else {
            content
        }
    }
}

/// Subtle press feedback only — no static row fill.
struct TrendCardRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
            }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Premium Trend cards (compiled with TrendAnalysisChrome for target membership)

struct TrendPremiumCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        TrendHealthMetricCard(action: nil, content: content)
    }
}
