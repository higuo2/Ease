import Foundation

struct MealSlot: Hashable, Identifiable, Sendable {
    let id: String
    var titleKey: String?
    var customTitle: String?

    static let breakfast = MealSlot(id: "breakfast", titleKey: "meal.breakfast")
    static let lunch = MealSlot(id: "lunch", titleKey: "meal.lunch")
    static let afternoonTea = MealSlot(id: "afternoonTea", titleKey: "meal.afternoonTea")
    static let dinner = MealSlot(id: "dinner", titleKey: "meal.dinner")
    static let lateNight = MealSlot(id: "lateNight", titleKey: "meal.lateNight")

    static let presets: [MealSlot] = [
        .breakfast, .lunch, .afternoonTea, .dinner, .lateNight
    ]

    static let legacyPhotoIDs: Set<String> = ["breakfast", "lunch", "dinner"]

    var storesInLegacyFields: Bool { Self.legacyPhotoIDs.contains(id) }
    var isCustom: Bool { id.hasPrefix("custom.") }

    var displayTitle: String {
        if let titleKey {
            return String(localized: String.LocalizationValue(titleKey))
        }
        return customTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? id
    }

    static func custom(title: String, id: String? = nil) -> MealSlot? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 24 else { return nil }
        return MealSlot(
            id: id ?? "custom.\(UUID().uuidString.lowercased())",
            customTitle: trimmed
        )
    }

    static func fromExtra(_ extra: ExtraMealPhoto) -> MealSlot {
        if let preset = presets.first(where: { $0.id == extra.id }) {
            return preset
        }
        return MealSlot(id: extra.id, customTitle: extra.title)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MealSlot, rhs: MealSlot) -> Bool {
        lhs.id == rhs.id
    }
}

struct ExtraMealPhoto: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var title: String?
    var fileName: String?

    var isCustom: Bool { id.hasPrefix("custom.") }

    static func decode(_ json: String?) -> [ExtraMealPhoto] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        guard let items = try? JSONDecoder().decode([ExtraMealPhoto].self, from: data) else {
            return []
        }
        return sanitize(items)
    }

    static func encode(_ items: [ExtraMealPhoto]) -> String? {
        let cleaned = sanitize(items)
        guard !cleaned.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(cleaned) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func sanitize(_ items: [ExtraMealPhoto]) -> [ExtraMealPhoto] {
        var seen = Set<String>()
        var result: [ExtraMealPhoto] = []
        for item in items {
            guard isAllowedID(item.id), seen.insert(item.id).inserted else { continue }
            let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(
                ExtraMealPhoto(
                    id: item.id,
                    title: (title?.isEmpty == false) ? title : nil,
                    fileName: item.fileName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            )
        }
        return result
    }

    static func isAllowedID(_ id: String) -> Bool {
        if id == MealSlot.afternoonTea.id || id == MealSlot.lateNight.id { return true }
        return id.hasPrefix("custom.") && id.count > "custom.".count
    }

}

extension Array where Element == ExtraMealPhoto {
    mutating func upsert(slot: MealSlot, fileName: String?) {
        guard ExtraMealPhoto.isAllowedID(slot.id) else { return }
        if let index = firstIndex(where: { $0.id == slot.id }) {
            self[index].fileName = fileName
            if let title = slot.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                self[index].title = title
            }
            if fileName == nil && !slot.isCustom {
                remove(at: index)
            }
        } else if fileName != nil || slot.isCustom {
            append(ExtraMealPhoto(id: slot.id, title: slot.customTitle, fileName: fileName))
        }
    }

    mutating func removeMeal(id: String) {
        removeAll { $0.id == id }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
