import Foundation

enum CalendarHelper {

    // MARK: - Date Range

    static func pastSevenDays(from date: Date = .now) -> [Date] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: date))
        }
    }

    // MARK: - Completion Check

    static func isCompleted(habit: Habit, on date: Date) -> Bool {
        habit.completionRecords.contains { record in
            Calendar.current.isDate(record.completedAt, inSameDayAs: date)
        }
    }

    // MARK: - Week Calculation

    static func weekStartDate(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    static func completionCountInWeek(habit: Habit, weekOf date: Date) -> Int {
        let start = weekStartDate(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return habit.completionRecords.filter { record in
            record.completedAt >= start && record.completedAt < end
        }.count
    }

    // MARK: - Applicability

    static func isApplicable(habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDate = calendar.startOfDay(for: date)
        let startOfCreated = calendar.startOfDay(for: habit.createdAt)
        return startOfDate >= startOfCreated
    }
}
