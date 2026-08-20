import SwiftUI
import UIKit

enum EasePalette {
    static let background = Color(UIColor.secondarySystemBackground)
    static let card = Color.white
    static let accent = Color(red: 0.545, green: 0.325, blue: 0.859)
    static let accentSoft = Color(red: 0.78, green: 0.64, blue: 0.95)
    static let primaryText = Color.black
    static let secondaryText = Color.gray
    static let track = Color.gray.opacity(0.1)
    static let chartMuted = Color.black.opacity(0.18)
    static let healthBar = Color.gray.opacity(0.28)
    static let sleepMint = Color(red: 216 / 255, green: 243 / 255, blue: 238 / 255)
    static let sleepTeal = Color(red: 0.32, green: 0.68, blue: 0.62)
    static let periodPink = Color(red: 248 / 255, green: 221 / 255, blue: 230 / 255)
    static let periodRose = Color(red: 0.78, green: 0.40, blue: 0.54)
    static let energyOrange = Color(red: 251 / 255, green: 228 / 255, blue: 208 / 255)
}

enum EaseFont {
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
