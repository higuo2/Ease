import SwiftUI
import UIKit

enum EasePalette {
    /// App wash `#F7F8F9`
    static let background = Color(red: 247 / 255, green: 248 / 255, blue: 249 / 255)
    /// Primary card `#FFFFFF`
    static let card = Color.white
    /// Recessed / nested `#F2F3F5`
    static let recessed = Color(red: 242 / 255, green: 243 / 255, blue: 245 / 255)
    /// Nested milk `#F5F5F7`
    static let milk = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)

    static let primaryText = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let secondaryText = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let track = Color.black.opacity(0.06)
    static let hairline = Color.black.opacity(0.06)
    static let chartMuted = Color.black.opacity(0.22)
    static let tooltip = Color.black
    static let healthBar = Color.gray.opacity(0.28)

    // MARK: - Morandi module fills (Weight home grid — do not retune)

    static let morandiSage = Color(red: 197 / 255, green: 206 / 255, blue: 195 / 255)
    static let morandiBlush = Color(red: 212 / 255, green: 193 / 255, blue: 192 / 255)
    static let morandiMist = Color(red: 201 / 255, green: 208 / 255, blue: 212 / 255)
    static let morandiSand = Color(red: 217 / 255, green: 207 / 255, blue: 197 / 255)
    static let morandiSleep = Color(red: 196 / 255, green: 210 / 255, blue: 208 / 255)
    static let morandiPeriod = Color(red: 220 / 255, green: 198 / 255, blue: 204 / 255)
    static let morandiEnergy = Color(red: 224 / 255, green: 208 / 255, blue: 190 / 255)

    // MARK: - Morandi red / green (progress, charts, deltas — slightly bright)

    static let morandiGreen = Color(red: 168 / 255, green: 210 / 255, blue: 176 / 255)
    static let morandiGreenDeep = Color(red: 88 / 255, green: 158 / 255, blue: 108 / 255)
    static let morandiRed = Color(red: 238 / 255, green: 172 / 255, blue: 164 / 255)
    static let morandiRedDeep = Color(red: 210 / 255, green: 108 / 255, blue: 100 / 255)

    static let morandiOat = Color(red: 244 / 255, green: 240 / 255, blue: 235 / 255)
    static let morandiSageDeep = morandiGreenDeep
    static let morandiMistDeep = Color(red: 98 / 255, green: 148 / 255, blue: 162 / 255)
    static let morandiPeriodDeep = Color(red: 188 / 255, green: 128 / 255, blue: 142 / 255)
    static let morandiSleepDeep = Color(red: 88 / 255, green: 162 / 255, blue: 148 / 255)
    static let morandiEnergyDeep = Color(red: 198 / 255, green: 142 / 255, blue: 98 / 255)

    /// BMI spectrum — brighter bar tints (tiles unchanged).
    static let morandiBarMist = Color(red: 186 / 255, green: 198 / 255, blue: 206 / 255)
    static let morandiBarSage = Color(red: 178 / 255, green: 198 / 255, blue: 172 / 255)
    static let morandiBarSand = Color(red: 228 / 255, green: 210 / 255, blue: 188 / 255)
    static let morandiBarBlush = Color(red: 224 / 255, green: 192 / 255, blue: 190 / 255)

    // MARK: - Semantic aliases

    static let coral = morandiRedDeep
    static let coralDeep = morandiRedDeep
    static let accent = morandiRedDeep
    static let accentSoft = morandiRed
    static let accentWarm = morandiRedDeep
    static let mint = morandiGreenDeep
    static let softTeal = morandiGreenDeep

    static let sleepMint = morandiSleep
    static let sleepTeal = morandiSleepDeep
    static let periodPink = morandiPeriod
    static let periodRose = morandiPeriodDeep
    static let energyOrange = morandiEnergy

    static let iconSleep = morandiMistDeep
    static let iconEnergy = morandiEnergyDeep
    static let iconPeriod = morandiPeriodDeep

    static let dietClean = morandiGreenDeep
    static let dietNormal = morandiEnergyDeep
    static let dietCheat = morandiPeriodDeep
    static let dietFasting = morandiMistDeep

    static var morandiProgressFill: LinearGradient {
        LinearGradient(
            colors: [morandiGreen, morandiGreenDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var chartLineGradient: LinearGradient {
        LinearGradient(
            colors: [morandiRed, morandiRedDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Weight down (negative delta) = green; up = red.
    static func deltaColor(_ delta: Double) -> Color {
        if delta < 0 { return morandiGreenDeep }
        if delta > 0 { return morandiRedDeep }
        return secondaryText
    }

    static func semanticDelta(_ delta: Double) -> Color {
        if delta < 0 { return morandiGreenDeep }
        if delta > 0 { return morandiRedDeep }
        return secondaryText
    }

    static func dietTint(_ status: DietStatus) -> Color {
        switch status {
        case .clean: dietClean
        case .normal: dietNormal
        case .cheat: dietCheat
        case .fasting: dietFasting
        }
    }
}

enum EaseFont {
    static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func hero(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}
