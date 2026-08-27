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
    /// Coral loss / positive direction `#FF5252`
    static let coral = Color(red: 1.0, green: 82 / 255, blue: 82 / 255)
    static let coralDeep = Color(red: 229 / 255, green: 57 / 255, blue: 53 / 255)
    /// Quiet mint / soft teal — weight down (progress) on Trend/Calendar
    static let mint = Color(red: 0.36, green: 0.72, blue: 0.58)
    static let softTeal = Color(red: 0.28, green: 0.66, blue: 0.60)
    /// Brand accent — coral, not purple
    static let accent = coral
    static let accentSoft = Color(red: 1.0, green: 0.72, blue: 0.70)
    static let accentWarm = Color(red: 1.0, green: 0.55, blue: 0.42)
    static let primaryText = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let secondaryText = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let track = Color.black.opacity(0.06)
    static let hairline = Color.black.opacity(0.06)
    static let chartMuted = Color.black.opacity(0.22)
    static let tooltip = Color.black
    static let healthBar = Color.gray.opacity(0.28)
    /// Sheet-only quiet tints
    static let sleepMint = Color(red: 216 / 255, green: 243 / 255, blue: 238 / 255)
    static let sleepTeal = Color(red: 0.32, green: 0.68, blue: 0.62)
    static let periodPink = Color(red: 248 / 255, green: 221 / 255, blue: 230 / 255)
    static let periodRose = Color(red: 0.78, green: 0.40, blue: 0.54)
    static let energyOrange = Color(red: 251 / 255, green: 228 / 255, blue: 208 / 255)
    /// Factor icon pastels (Trend advanced estimate)
    static let iconSleep = Color(red: 0.45, green: 0.55, blue: 0.88)
    static let iconEnergy = Color(red: 0.95, green: 0.62, blue: 0.28)
    static let iconPeriod = Color(red: 0.90, green: 0.48, blue: 0.58)
    /// Diet status tints
    static let dietClean = Color(red: 0.42, green: 0.70, blue: 0.52)
    static let dietNormal = Color(red: 0.92, green: 0.68, blue: 0.28)
    static let dietCheat = Color(red: 0.86, green: 0.42, blue: 0.40)
    static let dietFasting = Color(red: 0.46, green: 0.58, blue: 0.62)

    /// Quiet Morandi fills for home square modules
    static let morandiSage = Color(red: 197 / 255, green: 206 / 255, blue: 195 / 255)
    static let morandiBlush = Color(red: 212 / 255, green: 193 / 255, blue: 192 / 255)
    static let morandiMist = Color(red: 201 / 255, green: 208 / 255, blue: 212 / 255)
    static let morandiSand = Color(red: 217 / 255, green: 207 / 255, blue: 197 / 255)
    static let morandiSleep = Color(red: 196 / 255, green: 210 / 255, blue: 208 / 255)
    static let morandiPeriod = Color(red: 220 / 255, green: 198 / 255, blue: 204 / 255)
    static let morandiEnergy = Color(red: 224 / 255, green: 208 / 255, blue: 190 / 255)

    static var chartLineGradient: LinearGradient {
        LinearGradient(
            colors: [coralDeep, accentSoft],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Weight-tab brand: coral on loss.
    static func deltaColor(_ delta: Double) -> Color {
        if delta < 0 { return coral }
        if delta > 0 { return mint }
        return secondaryText
    }

    /// Trend / Calendar chips: teal when weight drops, warm coral when it rises.
    static func semanticDelta(_ delta: Double) -> Color {
        if delta < 0 { return softTeal }
        if delta > 0 { return accentWarm }
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
