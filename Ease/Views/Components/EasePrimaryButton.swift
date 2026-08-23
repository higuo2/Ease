import SwiftUI

struct EasePrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    var isBusy: Bool = false
    var usesAccent: Bool = false
    let action: () -> Void

    private var fill: Color {
        guard isEnabled && !isBusy else { return Color.gray.opacity(0.35) }
        return usesAccent ? EasePalette.accent : Color.black
    }

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
            .background(fill)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
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
                .foregroundStyle(Color.white)
                .frame(width: 58, height: 58)
                .background(Color.black, in: Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("dashboard.fab"))
    }
}

struct EaseField<Accessory: View>: View {
    let title: LocalizedStringKey
    var titleVerbatim: String? = nil
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var suffix: LocalizedStringKey? = nil
    var isInvalid: Bool = false
    var accessory: Accessory

    init(
        title: LocalizedStringKey,
        titleVerbatim: String? = nil,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        suffix: LocalizedStringKey? = nil,
        isInvalid: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.titleVerbatim = titleVerbatim
        self.placeholder = placeholder
        self._text = text
        self.suffix = suffix
        self.isInvalid = isInvalid
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let titleVerbatim {
                Text(verbatim: titleVerbatim)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            } else {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }
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
                accessory
            }
            Rectangle()
                .fill(isInvalid ? EasePalette.primaryText : EasePalette.track)
                .frame(height: isInvalid ? 1.5 : 1)
        }
    }
}

extension EaseField where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        titleVerbatim: String? = nil,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        suffix: LocalizedStringKey? = nil,
        isInvalid: Bool = false
    ) {
        self.init(
            title: title,
            titleVerbatim: titleVerbatim,
            placeholder: placeholder,
            text: text,
            suffix: suffix,
            isInvalid: isInvalid
        ) {
            EmptyView()
        }
    }
}
