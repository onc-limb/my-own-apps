import Foundation
import SwiftData

@Observable
final class TodayViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetching

    /// Fetch all habits from the store, sorted by sortOrder.
    func fetchHabits() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Today's Habits

    /// Returns the list of habits that should be displayed today.
    func habitsForToday() throws -> [Habit] {
        let allHabits = try fetchHabits()
        return allHabits.filter { shouldShowToday($0) }
    }

    /// Determines whether a habit should be shown today based on its frequency.
    /// - daily: always shown
    /// - weeklyN: shown only if this week's completion count < weeklyCount
    func shouldShowToday(_ habit: Habit) -> Bool {
        switch habit.frequencyType {
        case .daily:
            return true
        case .weeklyN:
            let completedThisWeek = completionCountThisWeek(for: habit)
            return completedThisWeek < habit.weeklyCount
        }
    }

    // MARK: - Completion

    /// Marks a habit as completed for today by creating a new CompletionRecord.
    func completeHabit(_ habit: Habit, durationSeconds: Int = 0) {
        let record = CompletionRecord(
            completedAt: Date(),
            durationSeconds: durationSeconds,
            habit: habit
        )
        habit.completionRecords.append(record)
        modelContext.insert(record)
    }

    /// Returns whether a habit has been completed today.
    func isCompletedToday(_ habit: Habit) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return habit.completionRecords.contains { record in
            calendar.isDate(record.completedAt, inSameDayAs: today)
        }
    }

    // MARK: - Progress Summary

    /// Returns a tuple of (completedCount, totalCount) for today's habits.
    func progressSummary() throws -> (completed: Int, total: Int) {
        let todayHabits = try habitsForToday()
        let completedCount = todayHabits.filter { isCompletedToday($0) }.count
        return (completed: completedCount, total: todayHabits.count)
    }

    // MARK: - Private Helpers

    /// Counts how many times the habit was completed in the current week (Monday-start).
    private func completionCountThisWeek(for habit: Habit) -> Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        return habit.completionRecords.filter { record in
            record.completedAt >= weekInterval.start && record.completedAt < weekInterval.end
        }.count
    }
}
