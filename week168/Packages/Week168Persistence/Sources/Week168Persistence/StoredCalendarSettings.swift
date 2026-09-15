import Foundation
import SwiftData
import Week168Domain

@Model
final class StoredCalendarSettings {
    var timeZoneIdentifier: String = "UTC"
    var dayStartHour: Int = 0
    var weekStartWeekday: Int = 2

    init(_ value: CalendarSettings) {
        update(value)
    }

    func update(_ value: CalendarSettings) {
        timeZoneIdentifier = value.timeZoneIdentifier
        dayStartHour = value.dayStartHour
        weekStartWeekday = value.weekStartWeekday
    }

    func domainValue() -> CalendarSettings {
        CalendarSettings(
            timeZoneIdentifier: timeZoneIdentifier,
            dayStartHour: dayStartHour,
            weekStartWeekday: weekStartWeekday
        )
    }
}
