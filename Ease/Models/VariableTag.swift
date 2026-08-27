import Foundation

struct VariableTag: Hashable, Codable, Sendable, Identifiable {
    static let customPrefix = "custom."

    static let period = VariableTag(unchecked: "period")
    static let travel = VariableTag(unchecked: "travel")
    static let bowel = VariableTag(unchecked: "bowel")
    static let swollen = VariableTag(unchecked: "swollen")
    static let alcohol = VariableTag(unchecked: "alcohol")
    static let lateNight = VariableTag(unchecked: "lateNight")

    static let presets: [VariableTag] = [
        .period, .travel, .bowel, .swollen, .alcohol, .lateNight
    ]

    let rawValue: String
    var id: String { rawValue }

    var isCustom: Bool { rawValue.hasPrefix(Self.customPrefix) }

    var systemImage: String {
        switch rawValue {
        case Self.period.rawValue: "drop.fill"
        case Self.travel.rawValue: "airplane"
        case Self.bowel.rawValue: "wind"
        case Self.swollen.rawValue: "humidity.fill"
        case Self.alcohol.rawValue: "wineglass"
        case Self.lateNight.rawValue: "moon.fill"
        default: "tag"
        }
    }

    var titleKey: String? {
        switch rawValue {
        case Self.period.rawValue: "tag.period"
        case Self.travel.rawValue: "tag.travel"
        case Self.bowel.rawValue: "tag.bowel"
        case Self.swollen.rawValue: "tag.swollen"
        case Self.alcohol.rawValue: "tag.alcohol"
        case Self.lateNight.rawValue: "tag.lateNight"
        default: nil
        }
    }

    var customLabel: String {
        guard isCustom else { return rawValue }
        return String(rawValue.dropFirst(Self.customPrefix.count))
    }

    init?(rawValue: String) {
        guard Self.isAllowed(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    static func custom(from displayName: String) -> VariableTag? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 24 else { return nil }
        let slug = trimmed
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard !slug.isEmpty else { return nil }
        return VariableTag(rawValue: customPrefix + slug)
    }

    static func sanitized(_ tags: [VariableTag]) -> [VariableTag] {
        var seen = Set<String>()
        var result: [VariableTag] = []
        for preset in presets where tags.contains(preset) && seen.insert(preset.rawValue).inserted {
            result.append(preset)
        }
        for tag in tags where tag.isCustom && seen.insert(tag.rawValue).inserted {
            result.append(tag)
        }
        return result
    }

    static func isAllowed(_ rawValue: String) -> Bool {
        if presets.contains(where: { $0.rawValue == rawValue }) { return true }
        guard rawValue.hasPrefix(customPrefix) else { return false }
        let label = String(rawValue.dropFirst(customPrefix.count))
        return !label.isEmpty
            && !label.contains("/")
            && !label.contains("\\")
            && !label.contains(";")
            && label.count <= 24
    }

    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }
}
