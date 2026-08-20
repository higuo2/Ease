import Foundation
import UserNotifications
import SwiftData

@MainActor
enum NotificationScheduler {
    private static let weightPrefix = "ease.weight."
    private static let dietPrefix = "ease.diet."
    private static let horizonDays = 7

    static func refresh(
        enabled: Bool,
        context: ModelContext
    ) async {
        let today = try? DailyRecordRepository(context: context).record(on: .now)
        let logs = (try? WeightLogRepository(context: context).logs(on: .now)) ?? []
        let records = today.map { [$0] } ?? []
        let hasWeight = WeightMetrics.hasWeight(records: records, logs: logs, on: .now)
        let health = await HealthKitReader.load(days: 1)
        await refresh(
            enabled: enabled,
            todayRecord: today,
            hasWeightToday: hasWeight,
            healthToday: health[CalendarDay.dayKey(from: .now)]
        )
    }

    static func refresh(
        enabled: Bool,
        todayRecord: DailyRecord?,
        hasWeightToday: Bool = false,
        healthToday: HealthDaySnapshot?,
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        let center = UNUserNotificationCenter.current()
        await removePending(center: center)

        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let today = CalendarDay.startOfDay(now, calendar: calendar)
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let isToday = offset == 0
            let skipWeight = isToday && hasWeightToday
            let skipDiet = isToday && todayRecord?.dietStatus != nil
            if !skipWeight {
                await schedule(
                    center: center,
                    prefix: weightPrefix,
                    day: day,
                    hour: 8,
                    minute: 0,
                    body: weightBody(health: isToday ? healthToday : nil),
                    now: now,
                    calendar: calendar
                )
            }
            if !skipDiet {
                await schedule(
                    center: center,
                    prefix: dietPrefix,
                    day: day,
                    hour: 22,
                    minute: 30,
                    body: dietBody(health: isToday ? healthToday : nil),
                    now: now,
                    calendar: calendar
                )
            }
        }
    }

    private static func weightBody(health: HealthDaySnapshot?) -> String {
        var parts = [String(localized: "notify.weight")]
        appendContext(&parts, health: health)
        return parts.joined(separator: " ")
    }

    private static func dietBody(health: HealthDaySnapshot?) -> String {
        var parts = [String(localized: "notify.diet")]
        appendContext(&parts, health: health)
        return parts.joined(separator: " ")
    }

    private static func appendContext(_ parts: inout [String], health: HealthDaySnapshot?) {
        if health?.isMenstrual == true {
            parts.append(String(localized: "notify.period"))
        }
        if let sleep = health?.previousNightSleepHours, sleep < 6 {
            parts.append(String(localized: "notify.sleep"))
        }
    }

    private static func schedule(
        center: UNUserNotificationCenter,
        prefix: String,
        day: Date,
        hour: Int,
        minute: Int,
        body: String,
        now: Date,
        calendar: Calendar
    ) async {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let fireDate = calendar.date(from: components), fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = prefix + CalendarDay.dayKey(from: day, calendar: calendar)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func removePending(center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(weightPrefix) || $0.hasPrefix(dietPrefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
