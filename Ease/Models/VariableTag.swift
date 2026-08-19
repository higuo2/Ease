import Foundation

enum VariableTag: String, Codable, CaseIterable, Sendable {
    case period
    case travel
    case bowel

    var systemImage: String {
        switch self {
        case .period: "drop.fill"
        case .travel: "airplane"
        case .bowel: "wind"
        }
    }

    var titleKey: String {
        switch self {
        case .period: "tag.period"
        case .travel: "tag.travel"
        case .bowel: "tag.bowel"
        }
    }

    static func sanitized(_ tags: [VariableTag]) -> [VariableTag] {
        allCases.filter { tags.contains($0) }
    }
}
