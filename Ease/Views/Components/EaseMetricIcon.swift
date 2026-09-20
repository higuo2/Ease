import SwiftUI

/// 32×32 Morandi tile for measurement rows — matches Health-style metric icons.
struct EaseMetricIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(EasePalette.morandiRedDeep)
            .frame(width: 32, height: 32)
            .background(
                EasePalette.morandiOat,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
