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
