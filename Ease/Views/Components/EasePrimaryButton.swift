import SwiftUI

struct EasePrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background((isEnabled && !isBusy) ? Color.black : Color.gray.opacity(0.35))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isBusy)
    }
}

struct EaseTextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
        }
        .buttonStyle(.plain)
    }
}

struct EaseFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(EasePalette.accent)
                .frame(width: 58, height: 58)
                .background(Color.white, in: Circle())
                .overlay {
                    Circle()
                        .stroke(EasePalette.accent, lineWidth: 1.5)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("dashboard.fab"))
    }
}

struct EaseField: View {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var suffix: LocalizedStringKey? = nil
    var isInvalid: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
            HStack {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(EaseFont.number(22))
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
            Rectangle()
                .fill(isInvalid ? EasePalette.primaryText : EasePalette.track)
                .frame(height: isInvalid ? 1.5 : 1)
        }
    }
}
