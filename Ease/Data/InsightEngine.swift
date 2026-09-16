import Foundation

struct HealthInsight: Equatable, Identifiable, Sendable {
    enum Kind: String, Sendable {
        case shortSleepWeight
        case periodWeight
        case weekdaySleep
        case lowEnergyWeight
    }

    var kind: Kind
    var id: String { kind.rawValue }
    /// Effect size ÷ minimum threshold. Larger ranks first.
    var score: Double
    var inMean: Double
    var outMean: Double
    var inCount: Int
    var outCount: Int
    /// Calendar weekday of the *night* (1 = Sunday). Only for `weekdaySleep`.
    var weekday: Int?

    var symbolName: String {
        switch kind {
        case .shortSleepWeight, .weekdaySleep: "moon.fill"
        case .periodWeight: "drop.fill"
        case .lowEnergyWeight: "bolt.fill"
        }
    }

    var titleKey: String {
        switch kind {
        case .weekdaySleep:
            return "trend.insights.weekdaySleep.title"
        case .shortSleepWeight:
            return inMean >= outMean
                ? "trend.insights.shortSleepWeight.title.up"
                : "trend.insights.shortSleepWeight.title.down"
        case .periodWeight:
            return inMean >= outMean
                ? "trend.insights.periodWeight.title.up"
                : "trend.insights.periodWeight.title.down"
        case .lowEnergyWeight:
            return inMean >= outMean
                ? "trend.insights.lowEnergyWeight.title.up"
                : "trend.insights.lowEnergyWeight.title.down"
        }
    }

    var comparesWeight: Bool { kind != .weekdaySleep }

    var delta: Double { inMean - outMean }

    var sampleCount: Int { inCount + outCount }

    func localizedHeadline(locale: Locale = .current, calendar: Calendar = .current) -> String {
        switch kind {
        case .weekdaySleep:
            return String(
                format: String(localized: String.LocalizationValue(titleKey), locale: locale),
                locale: locale,
                weekdayHeadlineName(locale: locale, calendar: calendar)
            )
        case .shortSleepWeight, .periodWeight, .lowEnergyWeight:
            return String(localized: String.LocalizationValue(titleKey), locale: locale)
        }
    }

    func localizedTitle(locale: Locale = .current) -> String {
        localizedHeadline(locale: locale)
    }

    func inGroupLabel(locale: Locale = .current, calendar: Calendar = .current) -> String {
        switch kind {
        case .shortSleepWeight:
            return String(localized: "trend.insights.shortSleepWeight.in", locale: locale)
        case .periodWeight:
            return String(localized: "trend.insights.periodWeight.in", locale: locale)
        case .lowEnergyWeight:
            return String(localized: "trend.insights.lowEnergyWeight.in", locale: locale)
        case .weekdaySleep:
            return String(
                format: String(localized: "trend.insights.weekdaySleep.in", locale: locale),
                locale: locale,
                weekdayMetricName(locale: locale, calendar: calendar)
            )
        }
    }

    func outGroupLabel(locale: Locale = .current) -> String {
        switch kind {
        case .shortSleepWeight:
            return String(localized: "trend.insights.shortSleepWeight.out", locale: locale)
        case .periodWeight:
            return String(localized: "trend.insights.periodWeight.out", locale: locale)
        case .lowEnergyWeight:
            return String(localized: "trend.insights.lowEnergyWeight.out", locale: locale)
        case .weekdaySleep:
            return String(localized: "trend.insights.weekdaySleep.out", locale: locale)
        }
    }

    func inValueText() -> String {
        comparesWeight ? EaseFormatters.signedKg(inMean) : EaseFormatters.sleepDuration(inMean)
    }

    func outValueText() -> String {
        comparesWeight ? EaseFormatters.signedKg(outMean) : EaseFormatters.sleepDuration(outMean)
    }

    func deltaText() -> String {
        comparesWeight ? EaseFormatters.signedKg(delta) : EaseFormatters.signedSleepDelta(delta)
    }

    func sampleSizeText(locale: Locale = .current) -> String {
        let key = comparesWeight ? "trend.insights.sampleSize.days" : "trend.insights.sampleSize.nights"
        return String(
            format: String(localized: String.LocalizationValue(key), locale: locale),
            locale: locale,
            sampleCount
        )
    }

    func accessibilitySummary(locale: Locale = .current, calendar: Calendar = .current) -> String {
        [
            localizedHeadline(locale: locale, calendar: calendar),
            deltaText(),
            "\(inGroupLabel(locale: locale, calendar: calendar)) \(inValueText())",
            "\(outGroupLabel(locale: locale)) \(outValueText())",
            sampleSizeText(locale: locale)
        ].joined(separator: ", ")
    }

    func weekdayName(
        locale: Locale = .current,
        calendar: Calendar = .current,
        style: Date.FormatStyle.Symbol.Weekday = .wide
    ) -> String {
        guard let weekday else { return "" }
        var calendar = calendar
        calendar.locale = locale
        let today = CalendarDay.startOfDay(.now, calendar: calendar)
        for offset in 0..<7 {
            let date = CalendarDay.addingDays(offset, to: today, calendar: calendar)
            if calendar.component(.weekday, from: date) == weekday {
                var format = style == .abbreviated
                    ? EaseDateFormat.weekdayAbbreviated
                    : EaseDateFormat.weekdayWide
                format.locale = locale
                format.calendar = calendar
                return date.formatted(format)
            }
        }
        return ""
    }

    func weekdayHeadlineName(locale: Locale = .current, calendar: Calendar = .current) -> String {
        let wide = weekdayName(locale: locale, calendar: calendar, style: .wide)
        if locale.language.languageCode?.identifier == "en" {
            return "\(wide)s"
        }
        return weekdayName(locale: locale, calendar: calendar, style: .abbreviated)
    }

    func weekdayMetricName(locale: Locale = .current, calendar: Calendar = .current) -> String {
        if locale.language.languageCode?.identifier == "zh" {
            return weekdayName(locale: locale, calendar: calendar, style: .abbreviated)
        }
        return weekdayName(locale: locale, calendar: calendar, style: .wide)
    }
}

struct HealthInsightReport: Equatable, Sendable {
    var insights: [HealthInsight]

    var trend: [HealthInsight] {
        Array(insights.prefix(HealthInsightEngine.maxTrendInsights))
    }

    func first(of kind: HealthInsight.Kind) -> HealthInsight? {
        insights.first { $0.kind == kind }
    }

    var sleepNote: HealthInsight? {
        first(of: .weekdaySleep) ?? first(of: .shortSleepWeight)
    }

    var energyNote: HealthInsight? {
        first(of: .lowEnergyWeight)
    }
}

/// Cross-series facts for Trend. Association only — not cause, not medical advice.
enum HealthInsightEngine {
    static let lookbackDays = 90
    static let maxTrendInsights = 3
    static let minGroupCount = 4
    static let minLoggedNights = 14
    static let shortSleepHours = 6.0
    static let minWeightDeltaKg = 0.1
    static let minSleepDeltaHours = 0.5

    struct Series: Equatable, Sendable {
        var sleepHoursByDay: [String: Double]
        var energyKcalByDay: [String: Double]
        var periodDayKeys: Set<String>
    }

    static func series(
        healthByDay: [String: HealthDaySnapshot],
        sleepHistory: SleepHistory,
        energyHistory: EnergyHistory,
        cycleHistory: CycleHistory
    ) -> Series {
        var sleep: [String: Double] = [:]
        for night in sleepHistory.nights {
            if let hours = night.hours {
                sleep[night.dayKey] = hours
            }
        }
        for (key, snap) in healthByDay {
            if let hours = snap.previousNightSleepHours {
                sleep[key] = sleep[key] ?? hours
            }
        }

        var energy: [String: Double] = [:]
        for day in energyHistory.days {
            if let kcal = day.kcal {
                energy[day.dayKey] = kcal
            }
        }
        for (key, snap) in healthByDay {
            if let kcal = snap.activeEnergyKcal {
                energy[key] = energy[key] ?? kcal
            }
        }

        var period = cycleHistory.periodDayKeys
        for (key, snap) in healthByDay where snap.isMenstrual {
            period.insert(key)
        }

        return Series(
            sleepHoursByDay: sleep,
            energyKcalByDay: energy,
            periodDayKeys: period
        )
    }

    static func report(
        records: [DailyRecord],
        logs: [WeightLog],
        healthByDay: [String: HealthDaySnapshot],
        sleepHistory: SleepHistory,
        energyHistory: EnergyHistory,
        cycleHistory: CycleHistory,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> HealthInsightReport {
        evaluate(
            samples: WeightMetrics.samples(from: records, logs: logs, calendar: calendar),
            series: series(
                healthByDay: healthByDay,
                sleepHistory: sleepHistory,
                energyHistory: energyHistory,
                cycleHistory: cycleHistory
            ),
            now: now,
            calendar: calendar
        )
    }

    static func evaluate(
        samples: [WeightSample],
        series: Series,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> HealthInsightReport {
        let windowKeys = Set(
            CalendarDay.datesBack(lookbackDays, from: now, calendar: calendar)
                .map { CalendarDay.dayKey(from: $0, calendar: calendar) }
        )
        let deltas = consecutiveDeltas(samples: samples, windowKeys: windowKeys, calendar: calendar)
        var found: [HealthInsight] = []
        if let weekday = weekdaySleep(series: series, windowKeys: windowKeys, calendar: calendar) {
            found.append(weekday)
        }
        if let shortSleep = splitWeight(
            kind: .shortSleepWeight,
            deltas: deltas,
            inGroup: { delta in
                guard let hours = series.sleepHoursByDay[delta.dayKey] else { return nil }
                return hours < shortSleepHours
            }
        ) {
            found.append(shortSleep)
        }
        if let period = splitWeight(
            kind: .periodWeight,
            deltas: deltas,
            inGroup: { series.periodDayKeys.contains($0.dayKey) }
        ) {
            found.append(period)
        }
        let energyDeltas = deltas.filter { series.energyKcalByDay[$0.previousKey] != nil }
        let energyValues = energyDeltas.compactMap { series.energyKcalByDay[$0.previousKey] }
        if let medianEnergy = PaceEstimator.median(energyValues),
           let energy = splitWeight(
            kind: .lowEnergyWeight,
            deltas: energyDeltas,
            inGroup: { delta in
                guard let kcal = series.energyKcalByDay[delta.previousKey] else { return nil }
                return kcal < medianEnergy
            }
        ) {
            found.append(energy)
        }
        found.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return HealthInsightReport(insights: found)
    }

    private struct DayDelta {
        var date: Date
        var dayKey: String
        var previousKey: String
        var kg: Double
    }

    private static func consecutiveDeltas(
        samples: [WeightSample],
        windowKeys: Set<String>,
        calendar: Calendar
    ) -> [DayDelta] {
        let lastPerDay = WeightMetrics.lastPerDay(samples: samples, calendar: calendar)
        guard lastPerDay.count >= 2 else { return [] }
        var deltas: [DayDelta] = []
        for index in 1..<lastPerDay.count {
            let previous = lastPerDay[index - 1]
            let current = lastPerDay[index]
            let previousDay = CalendarDay.startOfDay(previous.date, calendar: calendar)
            let currentDay = CalendarDay.startOfDay(current.date, calendar: calendar)
            let gap = calendar.dateComponents([.day], from: previousDay, to: currentDay).day ?? 0
            guard gap == 1 else { continue }
            let key = CalendarDay.dayKey(from: currentDay, calendar: calendar)
            guard windowKeys.contains(key) else { continue }
            deltas.append(
                DayDelta(
                    date: currentDay,
                    dayKey: key,
                    previousKey: CalendarDay.dayKey(from: previousDay, calendar: calendar),
                    kg: current.weight - previous.weight
                )
            )
        }
        return deltas
    }

    private static func splitWeight(
        kind: HealthInsight.Kind,
        deltas: [DayDelta],
        inGroup: (DayDelta) -> Bool?
    ) -> HealthInsight? {
        var inside: [Double] = []
        var outside: [Double] = []
        for delta in deltas {
            guard let isInside = inGroup(delta) else { continue }
            if isInside {
                inside.append(delta.kg)
            } else {
                outside.append(delta.kg)
            }
        }
        guard let split = splitMeans(
            inGroup: inside,
            outGroup: outside,
            minDelta: minWeightDeltaKg,
            round: MeasurementBounds.roundedToTenth
        ) else { return nil }
        return HealthInsight(
            kind: kind,
            score: split.score,
            inMean: split.inMean,
            outMean: split.outMean,
            inCount: inside.count,
            outCount: outside.count
        )
    }

    private static func weekdaySleep(
        series: Series,
        windowKeys: Set<String>,
        calendar: Calendar
    ) -> HealthInsight? {
        var hoursByWeekday: [Int: [Double]] = [:]
        for (key, hours) in series.sleepHoursByDay {
            guard windowKeys.contains(key) else { continue }
            guard let morning = CalendarDay.date(fromDayKey: key, calendar: calendar) else { continue }
            let night = CalendarDay.addingDays(-1, to: morning, calendar: calendar)
            let weekday = calendar.component(.weekday, from: night)
            hoursByWeekday[weekday, default: []].append(hours)
        }
        let loggedCount = hoursByWeekday.values.reduce(0) { $0 + $1.count }
        guard loggedCount >= minLoggedNights else { return nil }

        var best: (weekday: Int, inMean: Double, outMean: Double, inCount: Int, outCount: Int, score: Double)?
        for (weekday, hours) in hoursByWeekday {
            let others = hoursByWeekday
                .filter { $0.key != weekday }
                .flatMap(\.value)
            guard let split = splitMeans(
                inGroup: hours,
                outGroup: others,
                minDelta: minSleepDeltaHours,
                round: MeasurementBounds.roundedToTenth
            ) else { continue }
            guard split.inMean < split.outMean else { continue }
            if best == nil || split.score > best!.score || (split.score == best!.score && weekday < best!.weekday) {
                best = (weekday, split.inMean, split.outMean, hours.count, others.count, split.score)
            }
        }
        guard let best else { return nil }
        return HealthInsight(
            kind: .weekdaySleep,
            score: best.score,
            inMean: best.inMean,
            outMean: best.outMean,
            inCount: best.inCount,
            outCount: best.outCount,
            weekday: best.weekday
        )
    }

    private static func splitMeans(
        inGroup: [Double],
        outGroup: [Double],
        minDelta: Double,
        round: (Double) -> Double
    ) -> (inMean: Double, outMean: Double, score: Double)? {
        guard inGroup.count >= minGroupCount, outGroup.count >= minGroupCount else { return nil }
        guard let inRaw = mean(inGroup), let outRaw = mean(outGroup) else { return nil }
        let inMean = round(inRaw)
        let outMean = round(outRaw)
        let delta = abs(inMean - outMean)
        guard delta >= minDelta else { return nil }
        return (inMean, outMean, delta / minDelta)
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
