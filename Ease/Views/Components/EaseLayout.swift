import SwiftUI

enum EaseLayout {
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let gridGap: CGFloat = 12
    static let tabBarScrollInset: CGFloat = 100
}

extension View {
    /// Outer padding for root-tab `ScrollView` content: 16pt sides, 100pt above the tab bar.
    func easeTabScrollContent() -> some View {
        padding(.horizontal, EaseLayout.screenPadding)
            .padding(.bottom, EaseLayout.tabBarScrollInset)
    }

    /// Matching inset-grouped `List` margins on the Settings tab.
    func easeTabListMargins() -> some View {
        contentMargins(.horizontal, EaseLayout.screenPadding, for: .scrollContent)
            .contentMargins(.bottom, EaseLayout.tabBarScrollInset, for: .scrollContent)
    }
}
