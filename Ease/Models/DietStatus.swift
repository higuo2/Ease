import Foundation

enum DietStatus: String, Codable, CaseIterable, Sendable {
    case clean
    case normal
    case cheat

    var systemImage: String {
        switch self {
        case .clean: "leaf.fill"
        case .normal: "fork.knife"
        case .cheat: "takeoutbag.and.cup.and.straw"
        }
    }

    var titleKey: String {
        switch self {
        case .clean: "diet.clean"
        case .normal: "diet.normal"
        case .cheat: "diet.cheat"
        }
    }
}
