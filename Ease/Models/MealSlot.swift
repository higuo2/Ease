import Foundation

enum MealSlot: String, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .breakfast: "meal.breakfast"
        case .lunch: "meal.lunch"
        case .dinner: "meal.dinner"
        }
    }
}
