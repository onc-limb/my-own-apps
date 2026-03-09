import Foundation

enum CalendarHelper {

    // MARK: - Logical Date

    /// Returns the logical start time of a given date.
    /// If dayStartHour is 4, returns that day's 4:00 AM.
    static func logicalStartOfDay(for date: Date, dayStartHour: Int) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: dayStartHour, to: startOfDay) ?? startOfDay
    }

    /// Returns the logical date that a given timestamp belongs to.
    /// If dayStartHour is 4 and the time is 3:59 AM, returns the previous day.
    static func logicalDate(for date: Date, dayStartHour: Int) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour < dayStartHour {
            let previousDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            return calendar.startOfDay(for: previousDay)
        }
        return calendar.startOfDay(for: date)
    }

    // MARK: - Date Range

    static func pastSevenDays(from date: Date = .now, dayStartHour: Int = 0) -> [Date] {
        let calendar = Calendar.current
        let baseDate = logicalDate(for: date, dayStartHour: dayStartHour)
        return (0..<7).reversed().compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: baseDate)
        }
    }

    // MARK: - Completion Check

    static func isCompleted(habit: Habit, on date: Date, dayStartHour: Int = 0) -> Bool {
        let logicalStart = logicalStartOfDay(for: date, dayStartHour: dayStartHour)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        let logicalEnd = logicalStartOfDay(for: nextDay, dayStartHour: dayStartHour)

        return habit.completionRecords.contains { record in
            record.completedAt >= logicalStart && record.completedAt < logicalEnd
        }
    }

    // MARK: - Week Calculation

    /// Returns the 7 days (Mon-Sun) of the week containing the given date.
    static func weekDays(for date: Date, dayStartHour: Int = 0) -> [Date] {
        let calendar = Calendar.current
        let monday = weekStartDate(for: date, dayStartHour: dayStartHour)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    static func weekStartDate(for date: Date, dayStartHour: Int = 0) -> Date {
        let calendar = Calendar.current
        let logical = logicalDate(for: date, dayStartHour: dayStartHour)
        // weekday: 1=Sun, 2=Mon, 3=Tue, ..., 7=Sat
        let weekday = calendar.component(.weekday, from: logical)
        // Days back to Monday: Mon(2)→0, Tue(3)→1, ..., Sun(1)→6
        let daysBack = (weekday - 2 + 7) % 7
        return calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: logical))!
    }

    static func completionCountInWeek(habit: Habit, weekOf date: Date, dayStartHour: Int = 0) -> Int {
        let start = weekStartDate(for: date, dayStartHour: dayStartHour)
        let logicalStart = logicalStartOfDay(for: start, dayStartHour: dayStartHour)
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return 0 }
        let logicalEnd = logicalStartOfDay(for: weekEnd, dayStartHour: dayStartHour)

        return habit.completionRecords.filter { record in
            record.completedAt >= logicalStart && record.completedAt < logicalEnd
        }.count
    }

    // MARK: - Default Weekdays

    /// Returns default weekdays for a given weekly count, prioritizing weekends first.
    /// Priority order: Sun(1) → Sat(7) → Fri(6) → Thu(5) → Wed(4) → Tue(3) → Mon(2)
    static func defaultWeekdays(for count: Int) -> [Int] {
        let priority = [1, 7, 6, 5, 4, 3, 2]
        let clamped = min(max(count, 0), 7)
        return Array(priority.prefix(clamped)).sorted()
    }

    // MARK: - Applicability

    static func isApplicable(habit: Habit, on date: Date, dayStartHour: Int = 0) -> Bool {
        let calendar = Calendar.current
        let logicalDay = logicalDate(for: date, dayStartHour: dayStartHour)
        let startOfCreated = calendar.startOfDay(for: habit.createdAt)
        return logicalDay >= startOfCreated
    }
}
