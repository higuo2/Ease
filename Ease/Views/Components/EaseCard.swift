import SwiftUI

struct EaseCard<Content: View>: View {
    private let fill: Color
    private let content: Content

    init(fill: Color = EasePalette.card, @ViewBuilder content: () -> Content) {
        self.fill = fill
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
    }
}
