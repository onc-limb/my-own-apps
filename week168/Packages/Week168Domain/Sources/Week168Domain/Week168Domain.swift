import Foundation

/// 集計に使う、端末の設定から独立した暦設定。
public struct CalendarSettings: Sendable, Equatable {
    public var timeZoneIdentifier: String
    public var dayStartHour: Int
    public var weekStartWeekday: Int

    public init(timeZoneIdentifier: String, dayStartHour: Int, weekStartWeekday: Int) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayStartHour = dayStartHour
        self.weekStartWeekday = weekStartWeekday
    }

    public enum ValidationError: Error, Equatable {
        case dayStartHourOutOfRange(Int)
        case weekStartWeekdayOutOfRange(Int)
        case unknownTimeZone(String)
    }

    /// 外部入力から作るときに使う。不正な設定はクラッシュせずエラーを返す。
    public static func validated(
        timeZoneIdentifier: String, dayStartHour: Int, weekStartWeekday: Int
    ) throws -> CalendarSettings {
        guard (0...6).contains(dayStartHour) else {
            throw ValidationError.dayStartHourOutOfRange(dayStartHour)
        }
        guard (1...7).contains(weekStartWeekday) else {
            throw ValidationError.weekStartWeekdayOutOfRange(weekStartWeekday)
        }
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw ValidationError.unknownTimeZone(timeZoneIdentifier)
        }
        return CalendarSettings(
            timeZoneIdentifier: timeZoneIdentifier,
            dayStartHour: dayStartHour,
            weekStartWeekday: weekStartWeekday
        )
    }
}

public struct LogicalDay: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public struct LogicalWeek: Sendable, Hashable, Comparable {
    public let startDay: LogicalDay

    public init(startDay: LogicalDay) {
        self.startDay = startDay
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.startDay < rhs.startDay
    }
}

public enum TimeAxis {
    public static func logicalDay(of instant: Date, settings: CalendarSettings) -> LogicalDay {
        let calendar = calendar(for: settings)
        let day = logicalDay(from: instant, calendar: calendar)
        let start = boundary(of: day, settings: settings, calendar: calendar)
        return instant < start ? addingDays(-1, to: day) : day
    }

    public static func logicalWeek(of day: LogicalDay, settings: CalendarSettings) -> LogicalWeek {
        validateSettings(settings)
        let calendar = labelCalendar
        let weekday = calendar.component(.weekday, from: date(of: day, calendar: calendar))
        let offset = (weekday - settings.weekStartWeekday + 7) % 7
        return LogicalWeek(startDay: addingDays(-offset, to: day))
    }

    /// 開始を含み、終了を含まない。所属判定に DateInterval.contains は使わない。
    public static func interval(of day: LogicalDay, settings: CalendarSettings) -> DateInterval {
        let calendar = calendar(for: settings)
        return DateInterval(
            start: boundary(of: day, settings: settings, calendar: calendar),
            end: boundary(of: addingDays(1, to: day), settings: settings, calendar: calendar)
        )
    }

    /// 7 日後の境界を暦から求める。経過時間が 168 時間とは限らない。
    public static func interval(of week: LogicalWeek, settings: CalendarSettings) -> DateInterval {
        let calendar = calendar(for: settings)
        return DateInterval(
            start: boundary(of: week.startDay, settings: settings, calendar: calendar),
            end: boundary(of: addingDays(7, to: week.startDay), settings: settings, calendar: calendar)
        )
    }

    public static func weeks(inYear year: Int, month: Int, settings: CalendarSettings) -> [LogicalWeek] {
        let firstDay = LogicalDay(year: year, month: month, day: 1)
        var start = logicalWeek(of: firstDay, settings: settings).startDay
        if start < firstDay {
            start = addingDays(7, to: start)
        }
        var result: [LogicalWeek] = []
        while start.year == year && start.month == month {
            result.append(LogicalWeek(startDay: start))
            start = addingDays(7, to: start)
        }
        return result
    }

    /// 集計用の重なり秒数。開始を含み、終了を含まない。
    public static func overlappingSeconds(of entry: DateInterval, within range: DateInterval) -> TimeInterval {
        let start = max(entry.start, range.start)
        let end = min(entry.end, range.end)
        guard start < end else { return 0 }
        // ASSUMPTION: 小数秒も保持するため秒数は TimeInterval とし、秒で合計してから表示・出力の直前に分へ切り捨てる。
        return end.timeIntervalSince(start)
    }

    /// 単一期間の表示用の便宜関数。記録ごとの戻り値を合計して集計してはいけない。
    /// 集計は overlappingSeconds の合計を求め、最後に一度だけ Int(totalSeconds / 60) に変換する。
    public static func overlappingMinutes(of entry: DateInterval, within range: DateInterval) -> Int {
        Int(overlappingSeconds(of: entry, within: range) / 60)
    }

    private static func calendar(for settings: CalendarSettings) -> Calendar {
        // ASSUMPTION: 暦はグレゴリオ暦。内部の無効な設定・日付は契約違反とし、外部入力は CalendarSettings.validated で検証する。
        validateSettings(settings)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: settings.timeZoneIdentifier)!
        return calendar
    }

    /// アプリ内部の契約検証。論理週のラベル演算でも設定全体の妥当性を要求する。
    private static func validateSettings(_ settings: CalendarSettings) {
        precondition((0...6).contains(settings.dayStartHour), "dayStartHour must be in 0...6")
        precondition((1...7).contains(settings.weekStartWeekday), "weekStartWeekday must be in 1...7")
        guard TimeZone(identifier: settings.timeZoneIdentifier) != nil else {
            preconditionFailure("Unknown time zone identifier")
        }
    }

    /// 日付ラベルの加減算専用。絶対時刻の境界は必ず設定のタイムゾーンで求める。
    private static var labelCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(of day: LogicalDay, calendar: Calendar) -> Date {
        let components = DateComponents(year: day.year, month: day.month, day: day.day)
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Unrepresentable logical day")
        }
        return date
    }

    private static func addingDays(_ count: Int, to day: LogicalDay) -> LogicalDay {
        let calendar = labelCalendar
        let date = date(of: day, calendar: calendar)
        precondition(logicalDay(from: date, calendar: calendar) == day, "Invalid logical day")
        return logicalDay(from: calendar.date(byAdding: .day, value: count, to: date)!, calendar: calendar)
    }

    private static func logicalDay(from date: Date, calendar: Calendar) -> LogicalDay {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return LogicalDay(year: components.year!, month: components.month!, day: components.day!)
    }

    private static func boundary(of day: LogicalDay, settings: CalendarSettings, calendar: Calendar) -> Date {
        // ASSUMPTION: 夏時間で開始時刻が欠ける場合は次の有効時刻、重複する場合は最初の時刻を使う。
        return calendar.date(
            bySettingHour: settings.dayStartHour, minute: 0, second: 0,
            of: date(of: day, calendar: calendar),
            matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward
        )!
    }
}
