import Foundation

enum StreakService {
    static func currentStreak(
        records: [DailyDraw],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let completedDays = Set(records.filter(\.completed).map {
            calendar.startOfDay(for: $0.drawnAt)
        })
        let todayStart = calendar.startOfDay(for: today)
        var cursor = completedDays.contains(todayStart)
            ? todayStart
            : calendar.date(byAdding: .day, value: -1, to: todayStart)!
        var result = 0

        while completedDays.contains(cursor) {
            result += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return result
    }
}
