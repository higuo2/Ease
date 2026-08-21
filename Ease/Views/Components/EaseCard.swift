import SwiftUI

struct EaseCard<Content: View>: View {
    private let fill: Color
    private let radius: CGFloat
    private let padding: CGFloat
    private let content: Content

    init(
        fill: Color = EasePalette.card,
        radius: CGFloat = 18,
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
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
