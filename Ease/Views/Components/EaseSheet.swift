import SwiftUI

extension View {
    func easeSheetPresentation() -> some View {
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
    }

    func easeNumericText<V: Equatable>(_ value: V) -> some View {
        self
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.25), value: value)
    }

    func easeHealthPlaceholder(_ isPlaceholder: Bool) -> some View {
        self
            .redacted(reason: isPlaceholder ? .placeholder : [])
            .animation(.easeInOut(duration: 0.25), value: isPlaceholder)
    }
}
