import SwiftUI

struct EaseCard<Content: View>: View {
    private let fill: Color
    private let radius: CGFloat
    private let padding: CGFloat
    private let accessibilityLabelKey: LocalizedStringKey?
    private let accessibilityHintKey: LocalizedStringKey?
    private let combinesChildren: Bool
    private let content: Content

    init(
        fill: Color = EasePalette.card,
        radius: CGFloat = 18,
        padding: CGFloat = 18,
        accessibilityLabel: LocalizedStringKey? = nil,
        accessibilityHint: LocalizedStringKey? = nil,
        combinesChildren: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.radius = radius
        self.padding = padding
        self.accessibilityLabelKey = accessibilityLabel
        self.accessibilityHintKey = accessibilityHint
        self.combinesChildren = combinesChildren
        self.content = content()
    }

    var body: some View {
        let card = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

        Group {
            if combinesChildren {
                card.accessibilityElement(children: .combine)
            } else {
                card
            }
        }
        .modifier(EaseOptionalA11y(label: accessibilityLabelKey, hint: accessibilityHintKey))
    }
}

struct EaseRecessedCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        EaseCard(fill: EasePalette.recessed, radius: 18, padding: 16) {
            content
        }
    }
}

private struct EaseOptionalA11y: ViewModifier {
    let label: LocalizedStringKey?
    let hint: LocalizedStringKey?

    func body(content: Content) -> some View {
        content
            .modifier(OptionalLabel(label: label))
            .modifier(OptionalHint(hint: hint))
    }
}

private struct OptionalLabel: ViewModifier {
    let label: LocalizedStringKey?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(Text(label))
        } else {
            content
        }
    }
}

private struct OptionalHint: ViewModifier {
    let hint: LocalizedStringKey?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let hint {
            content.accessibilityHint(Text(hint))
        } else {
            content
        }
    }
}
