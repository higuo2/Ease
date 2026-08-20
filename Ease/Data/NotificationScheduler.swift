import Foundation
import UserNotifications
import SwiftData

/// Pure scheduling rules. No `UNUserNotificationCenter` — safe to unit test with a fixed calendar.
enum NotificationSchedulePolicy {
    static let weightHour = 8
    static let weightMinute = 0
    static let dietHour = 22
    static let dietMinute = 30
    static let horizonDays = 7

    /// Weight reminder fires at the profile wall-clock time (default 08:00).
    static func shouldScheduleWeightReminder(
        on day: Date,
        now: Date,
        hasWeightToday: Bool,
        hour: Int = weightHour,
        minute: Int = weightMinute,
        calendar: Calendar
    ) -> Bool {
        shouldSchedule(
            on: day,
            now: now,
            hour: MeasurementBounds.clampedHour(hour),
            minute: MeasurementBounds.clampedMinute(minute),
            skipTodayIfAlreadyLogged: hasWeightToday,
            calendar: calendar
        )
    }

    static func shouldScheduleWeightReminder(
        on day: Date,
        now: Date,
        logs: [WeightLog],
        records: [DailyRecord] = [],
        hour: Int = weightHour,
        minute: Int = weightMinute,
        calendar: Calendar
    ) -> Bool {
        let hasWeightToday = WeightMetrics.hasWeight(
            records: records,
            logs: logs,
            on: now,
            calendar: calendar
        )
        return shouldScheduleWeightReminder(
            on: day,
            now: now,
            hasWeightToday: hasWeightToday,
            hour: hour,
            minute: minute,
            calendar: calendar
        )
    }

    /// Diet reminder fires at the profile wall-clock time (default 22:30).
    static func shouldScheduleDietReminder(
        on day: Date,
        now: Date,
        hasDietStatusToday: Bool,
        hour: Int = dietHour,
        minute: Int = dietMinute,
        calendar: Calendar
    ) -> Bool {
        shouldSchedule(
            on: day,
            now: now,
            hour: MeasurementBounds.clampedHour(hour),
            minute: MeasurementBounds.clampedMinute(minute),
            skipTodayIfAlreadyLogged: hasDietStatusToday,
            calendar: calendar
        )
    }

    static func shouldScheduleDietReminder(
        on day: Date,
        now: Date,
        todayRecord: DailyRecord?,
        hour: Int = dietHour,
        minute: Int = dietMinute,
        calendar: Calendar
    ) -> Bool {
        shouldScheduleDietReminder(
            on: day,
            now: now,
            hasDietStatusToday: todayRecord?.dietStatus != nil,
            hour: hour,
            minute: minute,
            calendar: calendar
        )
    }

    static func shouldSchedule(
        on day: Date,
        now: Date,
        hour: Int,
        minute: Int,
        skipTodayIfAlreadyLogged: Bool,
        calendar: Calendar
    ) -> Bool {
        let dayStart = CalendarDay.startOfDay(day, calendar: calendar)
        let todayStart = CalendarDay.startOfDay(now, calendar: calendar)
        guard dayStart >= todayStart else { return false }
        if calendar.isDate(dayStart, inSameDayAs: todayStart), skipTodayIfAlreadyLogged {
            return false
        }
        let fireDate = CalendarDay.atHour(hour, minute: minute, on: dayStart, calendar: calendar)
        return fireDate > now
    }
}

@MainActor
enum NotificationScheduler {
    private static let weightPrefix = "ease.weight."
    private static let dietPrefix = "ease.diet."

    static func refresh(
        enabled: Bool,
        context: ModelContext
    ) async {
        let today = try? DailyRecordRepository(context: context).record(on: .now)
        let logs = (try? WeightLogRepository(context: context).logs(on: .now)) ?? []
        let records = today.map { [$0] } ?? []
        let hasWeight = WeightMetrics.hasWeight(records: records, logs: logs, on: .now)
        let profileDescriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let profile = try? context.fetch(profileDescriptor).first
        let health = await HealthKitReader.load(days: 1)
        await refresh(
            enabled: enabled,
            todayRecord: today,
            hasWeightToday: hasWeight,
            healthToday: health[CalendarDay.dayKey(from: .now)],
            weightHour: profile?.weightReminderHour ?? NotificationSchedulePolicy.weightHour,
            weightMinute: profile?.weightReminderMinute ?? NotificationSchedulePolicy.weightMinute,
            dietHour: profile?.dietReminderHour ?? NotificationSchedulePolicy.dietHour,
            dietMinute: profile?.dietReminderMinute ?? NotificationSchedulePolicy.dietMinute
        )
    }

    static func refresh(
        enabled: Bool,
        todayRecord: DailyRecord?,
        hasWeightToday: Bool = false,
        healthToday: HealthDaySnapshot?,
        weightHour: Int = NotificationSchedulePolicy.weightHour,
        weightMinute: Int = NotificationSchedulePolicy.weightMinute,
        dietHour: Int = NotificationSchedulePolicy.dietHour,
        dietMinute: Int = NotificationSchedulePolicy.dietMinute,
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
        let clampedWeightHour = MeasurementBounds.clampedHour(weightHour)
        let clampedWeightMinute = MeasurementBounds.clampedMinute(weightMinute)
        let clampedDietHour = MeasurementBounds.clampedHour(dietHour)
        let clampedDietMinute = MeasurementBounds.clampedMinute(dietMinute)
        for offset in 0..<NotificationSchedulePolicy.horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: day,
                now: now,
                hasWeightToday: hasWeightToday,
                hour: clampedWeightHour,
                minute: clampedWeightMinute,
                calendar: calendar
            ) {
                await schedule(
                    center: center,
                    prefix: weightPrefix,
                    day: day,
                    hour: clampedWeightHour,
                    minute: clampedWeightMinute,
                    body: weightBody(health: offset == 0 ? healthToday : nil),
                    now: now,
                    calendar: calendar
                )
            }
            if NotificationSchedulePolicy.shouldScheduleDietReminder(
                on: day,
                now: now,
                hasDietStatusToday: todayRecord?.dietStatus != nil,
                hour: clampedDietHour,
                minute: clampedDietMinute,
                calendar: calendar
            ) {
                await schedule(
                    center: center,
                    prefix: dietPrefix,
                    day: day,
                    hour: clampedDietHour,
                    minute: clampedDietMinute,
                    body: dietBody(health: offset == 0 ? healthToday : nil),
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
        components.timeZone = calendar.timeZone
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
