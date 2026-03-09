import Foundation
import SwiftData

@Observable
final class TodayViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let dayStartHour: Int

    // MARK: - State

    var selectedDate: Date

    // MARK: - Init

    init(modelContext: ModelContext, dayStartHour: Int = 0) {
        self.modelContext = modelContext
        self.dayStartHour = dayStartHour
        self.selectedDate = CalendarHelper.logicalDate(for: Date(), dayStartHour: dayStartHour)
    }

    // MARK: - Computed

    var isToday: Bool {
        let today = CalendarHelper.logicalDate(for: Date(), dayStartHour: dayStartHour)
        return Calendar.current.isDate(selectedDate, inSameDayAs: today)
    }

    // MARK: - Fetching

    /// Fetch active habits from the store, sorted by sortOrder.
    func fetchHabits() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let allHabits = try modelContext.fetch(descriptor)
        return allHabits.filter { $0.isActive }
    }

    // MARK: - Habit Visibility

    /// Determines whether a habit should be shown on the given date.
    func shouldShow(_ habit: Habit, on date: Date) -> Bool {
        switch habit.frequencyType {
        case .daily:
            return true
        case .weeklyN:
            if !habit.effectiveWeekdays.isEmpty {
                let weekday = Calendar.current.component(.weekday, from: date)
                if !habit.effectiveWeekdays.contains(weekday) {
                    return false
                }
            }
            let completedThisWeek = CalendarHelper.completionCountInWeek(
                habit: habit, weekOf: date, dayStartHour: dayStartHour
            )
            return completedThisWeek < habit.weeklyCount
        }
    }

    /// Backward-compatible wrapper that uses selectedDate.
    func shouldShowToday(_ habit: Habit) -> Bool {
        shouldShow(habit, on: selectedDate)
    }

    /// Returns the list of habits that should be displayed on the selected date.
    func habitsForToday() throws -> [Habit] {
        let allHabits = try fetchHabits()
        return allHabits.filter { shouldShowToday($0) }
    }

    // MARK: - Backyard

    /// Moves a habit to the backyard (sets isActive to false).
    func moveToBackyard(_ habit: Habit) {
        habit.isActive = false
    }

    /// Activates a habit from the backyard (sets isActive to true).
    func activateHabit(_ habit: Habit) {
        habit.isActive = true
    }

    // MARK: - Completion

    /// Returns whether a habit has been completed on the given date.
    func isCompleted(_ habit: Habit, on date: Date) -> Bool {
        CalendarHelper.isCompleted(habit: habit, on: date, dayStartHour: dayStartHour)
    }

    /// Backward-compatible wrapper that uses selectedDate.
    func isCompletedToday(_ habit: Habit) -> Bool {
        isCompleted(habit, on: selectedDate)
    }

    /// Marks a habit as completed for the given date (defaults to selectedDate).
    func completeHabit(_ habit: Habit, on date: Date? = nil, durationSeconds: Int = 0) {
        let targetDate = date ?? selectedDate
        let logicalStart = CalendarHelper.logicalStartOfDay(for: targetDate, dayStartHour: dayStartHour)
        let record = CompletionRecord(
            completedAt: logicalStart,
            durationSeconds: durationSeconds,
            habit: habit
        )
        habit.completionRecords.append(record)
        modelContext.insert(record)
    }

    /// Reverts a habit's completion for the given date (defaults to selectedDate).
    func uncompleteHabit(_ habit: Habit, on date: Date? = nil) {
        let targetDate = date ?? selectedDate
        let logicalStart = CalendarHelper.logicalStartOfDay(for: targetDate, dayStartHour: dayStartHour)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        let logicalEnd = CalendarHelper.logicalStartOfDay(for: nextDay, dayStartHour: dayStartHour)

        let recordsToDelete = habit.completionRecords.filter { record in
            record.completedAt >= logicalStart && record.completedAt < logicalEnd
        }

        for record in recordsToDelete {
            habit.completionRecords.removeAll { $0.persistentModelID == record.persistentModelID }
            modelContext.delete(record)
        }
    }

    // MARK: - Progress Summary

    /// Returns a tuple of (completedCount, totalCount) for today's habits.
    func progressSummary() throws -> (completed: Int, total: Int) {
        let todayHabits = try habitsForToday()
        let completedCount = todayHabits.filter { isCompletedToday($0) }.count
        return (completed: completedCount, total: todayHabits.count)
    }

    /// Returns the completion rate for today's habits as a value between 0.0 and 1.0.
    func completionRate() throws -> Double {
        let summary = try progressSummary()
        guard summary.total > 0 else { return 0.0 }
        return Double(summary.completed) / Double(summary.total)
    }
}
