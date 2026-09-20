import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum EaseKeyboard {
    @MainActor
    static func dismiss() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

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
    /// Apply the same 16pt inset to `.scrollContent` and `.automatic` so section
    /// titles and white cards share one leading edge.
    func easeTabListMargins() -> some View {
        contentMargins(.horizontal, EaseLayout.screenPadding, for: .scrollContent)
            .contentMargins(.horizontal, EaseLayout.screenPadding, for: .automatic)
            .contentMargins(.bottom, EaseLayout.tabBarScrollInset, for: .scrollContent)
    }
}
