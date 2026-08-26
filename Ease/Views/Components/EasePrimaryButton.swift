import SwiftUI

struct EasePrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    var isBusy: Bool = false
    var usesAccent: Bool = false
    var accessibilityHint: LocalizedStringKey? = nil
    let action: () -> Void

    private var fill: Color {
        guard isEnabled && !isBusy else { return Color.gray.opacity(0.35) }
        return usesAccent ? EasePalette.accent : Color.black
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.body.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Color.white)
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView()
                        .tint(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(fill)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isBusy)
        .accessibilityLabel(Text(title))
        .modifier(OptionalAccessibilityHint(hint: accessibilityHint))
        .accessibilityAddTraits(.isButton)
    }
}

private struct OptionalAccessibilityHint: ViewModifier {
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

struct EaseTextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(EasePalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
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
                    .font(.subheadline)
                    .foregroundStyle(EasePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(EasePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .firstTextBaseline) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(EasePalette.primaryText)
                    .minimumScaleFactor(0.7)
                if let suffix {
                    Text(suffix)
                        .font(.subheadline)
                        .foregroundStyle(EasePalette.secondaryText)
                        .fixedSize()
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
