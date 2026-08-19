import Foundation

enum VariableTag: String, Codable, CaseIterable, Sendable {
    case period = "drop.fill"
    case travel = "airplane"
    case bowel = "wind"

    var systemImage: String { rawValue }

    static func sanitized(_ tags: [VariableTag]) -> [VariableTag] {
        allCases.filter { tags.contains($0) }
    }
}
