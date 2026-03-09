import XCTest
import SwiftData
@testable import Habiterm

final class HabitermTests: XCTestCase {

    // MARK: - TodayViewModel Tests

    @MainActor func test_completionRate_noHabits_returnsZero() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel(modelContext: context)

        // Act
        let rate = try vm.completionRate()

        // Assert
        XCTAssertEqual(rate, 0.0)
    }

    @MainActor func test_progressSummary_threeHabitsTwoCompleted_returnsTwoAndThree() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel(modelContext: context)

        let habit1 = Habit(name: "H1", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        let habit2 = Habit(name: "H2", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 2)
        let habit3 = Habit(name: "H3", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 3)
        context.insert(habit1)
        context.insert(habit2)
        context.insert(habit3)

        vm.completeHabit(habit1)
        vm.completeHabit(habit2)

        // Act
        let summary = try vm.progressSummary()

        // Assert
        XCTAssertEqual(summary.completed, 2)
        XCTAssertEqual(summary.total, 3)
    }

    @MainActor func test_habitsForToday_weeklyNCompleted_notIncluded() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel(modelContext: context)

        let habit = Habit(name: "WeeklyHabit", timeLimitMinutes: 25, frequencyType: .weeklyN, weeklyCount: 2, sortOrder: 1)
        context.insert(habit)

        vm.completeHabit(habit)
        vm.completeHabit(habit)

        // Act
        let todayHabits = try vm.habitsForToday()

        // Assert
        XCTAssertFalse(todayHabits.contains(where: { $0.name == "WeeklyHabit" }))
    }

    @MainActor func test_completeHabit_createsCompletionRecord() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel(modelContext: context)

        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)

        // Act
        vm.completeHabit(habit, durationSeconds: 120)

        // Assert
        XCTAssertEqual(habit.completionRecords.count, 1)
        XCTAssertEqual(habit.completionRecords.first?.durationSeconds, 120)
    }

    @MainActor func test_isCompletedToday_completedToday_returnsTrue() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel(modelContext: context)

        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)
        vm.completeHabit(habit)

        // Act
        let result = vm.isCompletedToday(habit)

        // Assert
        XCTAssertTrue(result)
    }

    @MainActor func test_isCompletedToday_notCompleted_returnsFalse() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let vm = TodayViewModel(modelContext: context)

        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)

        // Act
        let result = vm.isCompletedToday(habit)

        // Assert
        XCTAssertFalse(result)
    }

    // MARK: - HabitFormViewModel Tests

    @MainActor func test_save_newHabit_insertsIntoContext() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let vm = HabitFormViewModel(modelContext: context)
        vm.name = "NewHabit"
        vm.timeLimitMinutes = 30
        vm.frequencyType = .daily

        // Act
        try vm.save()

        // Assert
        let descriptor = FetchDescriptor<Habit>()
        let habits = try context.fetch(descriptor)
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits.first?.name, "NewHabit")
        XCTAssertEqual(habits.first?.timeLimitMinutes, 30)
    }

    @MainActor func test_save_existingHabit_updatesProperties() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext

        let existingHabit = Habit(name: "OldName", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(existingHabit)

        let vm = HabitFormViewModel(modelContext: context, habit: existingHabit)
        vm.name = "UpdatedName"
        vm.timeLimitMinutes = 45

        // Act
        try vm.save()

        // Assert
        XCTAssertEqual(existingHabit.name, "UpdatedName")
        XCTAssertEqual(existingHabit.timeLimitMinutes, 45)
    }

    @MainActor func test_delete_removesHabitFromContext() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext

        let habit = Habit(name: "ToDelete", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)

        let vm = HabitFormViewModel(modelContext: context, habit: habit)

        // Act
        vm.delete()

        // Assert
        let descriptor = FetchDescriptor<Habit>()
        let habits = try context.fetch(descriptor)
        XCTAssertEqual(habits.count, 0)
    }

    // MARK: - TimerViewModel Tests

    @MainActor func test_timer_init_remainingSecondsEqualsTotalSeconds() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TimerHabit", timeLimitMinutes: 5, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)

        // Act
        let vm = TimerViewModel(habit: habit)

        // Assert
        XCTAssertEqual(vm.remainingSeconds, vm.totalSeconds)
        XCTAssertEqual(vm.totalSeconds, 5 * 60)

        vm.cleanup()
    }

    @MainActor func test_timer_start_setsStateToRunning() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TimerHabit", timeLimitMinutes: 5, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)
        let vm = TimerViewModel(habit: habit)

        // Act
        vm.start()

        // Assert
        XCTAssertEqual(vm.timerState, .running)

        vm.cleanup()
    }

    @MainActor func test_timer_pause_setsStateToPaused() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TimerHabit", timeLimitMinutes: 5, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)
        let vm = TimerViewModel(habit: habit)
        vm.start()

        // Act
        vm.pause()

        // Assert
        XCTAssertEqual(vm.timerState, .paused)

        vm.cleanup()
    }

    @MainActor func test_timer_resume_setsStateToRunning() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TimerHabit", timeLimitMinutes: 5, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)
        let vm = TimerViewModel(habit: habit)
        vm.start()
        vm.pause()

        // Act
        vm.resume()

        // Assert
        XCTAssertEqual(vm.timerState, .running)

        vm.cleanup()
    }

    @MainActor func test_timer_reset_setsStateToIdleAndResetsSeconds() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TimerHabit", timeLimitMinutes: 5, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)
        let vm = TimerViewModel(habit: habit)
        vm.start()

        // Act
        vm.reset()

        // Assert
        XCTAssertEqual(vm.timerState, .idle)
        XCTAssertEqual(vm.remainingSeconds, vm.totalSeconds)

        vm.cleanup()
    }

    @MainActor func test_timer_elapsedSeconds_returnsDifference() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TimerHabit", timeLimitMinutes: 5, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)
        let vm = TimerViewModel(habit: habit)

        // Act & Assert
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertEqual(vm.elapsedSeconds, vm.totalSeconds - vm.remainingSeconds)

        vm.cleanup()
    }

    // MARK: - CalendarHelper Tests

    @MainActor func test_pastSevenDays_returnsSevenDates() throws {
        // Act
        let days = CalendarHelper.pastSevenDays()

        // Assert
        XCTAssertEqual(days.count, 7)
    }

    @MainActor func test_pastSevenDays_datesAreStartOfDay() throws {
        // Act
        let days = CalendarHelper.pastSevenDays()

        // Assert
        let calendar = Calendar.current
        for day in days {
            XCTAssertEqual(day, calendar.startOfDay(for: day))
        }
    }

    @MainActor func test_pastSevenDays_orderedOldestFirst() throws {
        // Act
        let days = CalendarHelper.pastSevenDays()

        // Assert
        for i in 0..<days.count - 1 {
            XCTAssertTrue(days[i] < days[i + 1])
        }
    }

    @MainActor func test_isCompleted_withRecord_returnsTrue() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)

        let today = Calendar.current.startOfDay(for: Date())
        let record = CompletionRecord(completedAt: today, durationSeconds: 0, habit: habit)
        habit.completionRecords.append(record)
        context.insert(record)

        // Act
        let result = CalendarHelper.isCompleted(habit: habit, on: today)

        // Assert
        XCTAssertTrue(result)
    }

    @MainActor func test_isCompleted_withoutRecord_returnsFalse() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext
        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)

        // Act
        let today = Calendar.current.startOfDay(for: Date())
        let result = CalendarHelper.isCompleted(habit: habit, on: today)

        // Assert
        XCTAssertFalse(result)
    }

    @MainActor func test_isApplicable_beforeCreatedAt_returnsFalse() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext

        let createdAt = Date()
        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1, createdAt: createdAt)
        context.insert(habit)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: createdAt)!

        // Act
        let result = CalendarHelper.isApplicable(habit: habit, on: yesterday)

        // Assert
        XCTAssertFalse(result)
    }

    @MainActor func test_isApplicable_afterCreatedAt_returnsTrue() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext

        let createdAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1, createdAt: createdAt)
        context.insert(habit)

        let testDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // Act
        let result = CalendarHelper.isApplicable(habit: habit, on: testDate)

        // Assert
        XCTAssertTrue(result)
    }

    @MainActor func test_weekStartDate_returnsMonday() throws {
        // Arrange — 2026-02-25 is a Wednesday
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 25
        let wednesday = Calendar.current.date(from: components)!

        // Act
        let weekStart = CalendarHelper.weekStartDate(for: wednesday)

        // Assert
        let weekday = Calendar.current.component(.weekday, from: weekStart)
        XCTAssertEqual(weekday, 2) // 2 = Monday
    }

    @MainActor func test_weekStartDate_mondayReturnsSameMonday() throws {
        // Arrange — 2026-03-02 is a Monday
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        let monday = Calendar.current.date(from: components)!

        // Act
        let weekStart = CalendarHelper.weekStartDate(for: monday)

        // Assert — weekStart should be the same Monday
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: weekStart), 2) // Monday
        XCTAssertEqual(cal.component(.day, from: weekStart), 2)
        XCTAssertEqual(cal.component(.month, from: weekStart), 3)
    }

    @MainActor func test_weekStartDate_sundayReturnsPreviousMonday() throws {
        // Arrange — 2026-03-01 is a Sunday
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 1
        let sunday = Calendar.current.date(from: components)!

        // Act
        let weekStart = CalendarHelper.weekStartDate(for: sunday)

        // Assert — weekStart should be Monday 2026-02-23
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: weekStart), 2) // Monday
        XCTAssertEqual(cal.component(.day, from: weekStart), 23)
        XCTAssertEqual(cal.component(.month, from: weekStart), 2)
    }

    @MainActor func test_weekStartDate_withDayStartHour_beforeHour_returnsPreviousLogicalWeek() throws {
        // Arrange — 2026-03-02 (Monday) at 03:59 with dayStartHour=4
        // Logical date should be 2026-03-01 (Sunday), so week start = 2026-02-23 (Monday)
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        components.hour = 3
        components.minute = 59
        let earlyMonday = Calendar.current.date(from: components)!

        // Act
        let weekStart = CalendarHelper.weekStartDate(for: earlyMonday, dayStartHour: 4)

        // Assert — logical date is Sunday 3/1, so week start is Monday 2/23
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: weekStart), 2) // Monday
        XCTAssertEqual(cal.component(.day, from: weekStart), 23)
        XCTAssertEqual(cal.component(.month, from: weekStart), 2)
    }

    @MainActor func test_weekStartDate_withDayStartHour_afterHour_returnsCurrentWeek() throws {
        // Arrange — 2026-03-02 (Monday) at 04:00 with dayStartHour=4
        // Logical date should be 2026-03-02 (Monday), so week start = 2026-03-02
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        components.hour = 4
        components.minute = 0
        let mondayAfterStart = Calendar.current.date(from: components)!

        // Act
        let weekStart = CalendarHelper.weekStartDate(for: mondayAfterStart, dayStartHour: 4)

        // Assert — week start is Monday 3/2
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: weekStart), 2) // Monday
        XCTAssertEqual(cal.component(.day, from: weekStart), 2)
        XCTAssertEqual(cal.component(.month, from: weekStart), 3)
    }

    @MainActor func test_weekDays_returnsSevenDaysFromMondayToSunday() throws {
        // Arrange — 2026-03-04 is a Wednesday
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 4
        let wednesday = Calendar.current.date(from: components)!

        // Act
        let days = CalendarHelper.weekDays(for: wednesday)

        // Assert
        let cal = Calendar.current
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(cal.component(.weekday, from: days[0]), 2) // Monday
        XCTAssertEqual(cal.component(.weekday, from: days[6]), 1) // Sunday
        XCTAssertEqual(cal.component(.day, from: days[0]), 2) // March 2
        XCTAssertEqual(cal.component(.day, from: days[6]), 8) // March 8
    }

    @MainActor func test_completionCountInWeek_returnsCorrectCount() throws {
        // Arrange
        let container = try ModelContainerHelper.makeContainer()
        let context = container.mainContext

        let habit = Habit(name: "TestHabit", timeLimitMinutes: 25, frequencyType: .daily, weeklyCount: 7, sortOrder: 1)
        context.insert(habit)

        let today = Date()
        for i in 0..<3 {
            let date = Calendar.current.date(byAdding: .hour, value: -i, to: today)!
            let record = CompletionRecord(completedAt: date, durationSeconds: 0, habit: habit)
            habit.completionRecords.append(record)
            context.insert(record)
        }

        // Act
        let count = CalendarHelper.completionCountInWeek(habit: habit, weekOf: today)

        // Assert
        XCTAssertEqual(count, 3)
    }

    // MARK: - CalendarHelper.defaultWeekdays Tests

    func test_defaultWeekdays_count1_returnsSunday() {
        // Act
        let result = CalendarHelper.defaultWeekdays(for: 1)

        // Assert — Sun(1)
        XCTAssertEqual(result, [1])
    }

    func test_defaultWeekdays_count2_returnsSundayAndSaturday() {
        // Act
        let result = CalendarHelper.defaultWeekdays(for: 2)

        // Assert — Sun(1), Sat(7) sorted
        XCTAssertEqual(result, [1, 7])
    }

    func test_defaultWeekdays_count3_returnsSunSatFri() {
        // Act
        let result = CalendarHelper.defaultWeekdays(for: 3)

        // Assert — Sun(1), Fri(6), Sat(7) sorted
        XCTAssertEqual(result, [1, 6, 7])
    }

    func test_defaultWeekdays_count5_returnsFiveFromWeekend() {
        // Act
        let result = CalendarHelper.defaultWeekdays(for: 5)

        // Assert — Sun(1), Wed(4), Thu(5), Fri(6), Sat(7) sorted
        XCTAssertEqual(result, [1, 4, 5, 6, 7])
    }

    func test_defaultWeekdays_count7_returnsAllDays() {
        // Act
        let result = CalendarHelper.defaultWeekdays(for: 7)

        // Assert
        XCTAssertEqual(result, [1, 2, 3, 4, 5, 6, 7])
    }

    func test_defaultWeekdays_count0_returnsEmpty() {
        // Act
        let result = CalendarHelper.defaultWeekdays(for: 0)

        // Assert
        XCTAssertEqual(result, [])
    }

    // MARK: - Habit.effectiveWeekdays Tests

    func test_effectiveWeekdays_weeklyNWithEmptyAssigned_returnsDefaults() {
        // Arrange
        let habit = Habit(
            name: "Test", timeLimitMinutes: 0,
            frequencyType: .weeklyN, weeklyCount: 3,
            assignedWeekdays: [], sortOrder: 0
        )

        // Act
        let result = habit.effectiveWeekdays

        // Assert — defaults for count 3: Sun(1), Fri(6), Sat(7)
        XCTAssertEqual(result, [1, 6, 7])
    }

    func test_effectiveWeekdays_weeklyNWithAssigned_returnsAssigned() {
        // Arrange
        let habit = Habit(
            name: "Test", timeLimitMinutes: 0,
            frequencyType: .weeklyN, weeklyCount: 3,
            assignedWeekdays: [2, 4, 6], sortOrder: 0
        )

        // Act
        let result = habit.effectiveWeekdays

        // Assert — returns the explicit assignments
        XCTAssertEqual(result, [2, 4, 6])
    }

    func test_effectiveWeekdays_daily_returnsEmptyArray() {
        // Arrange
        let habit = Habit(
            name: "Test", timeLimitMinutes: 0,
            frequencyType: .daily, weeklyCount: 7,
            assignedWeekdays: [], sortOrder: 0
        )

        // Act
        let result = habit.effectiveWeekdays

        // Assert — daily habits return empty (shown every day)
        XCTAssertEqual(result, [])
    }

    func test_effectiveWeekdays_weeklyNCount2_returnsCorrectDefaults() {
        // Arrange
        let habit = Habit(
            name: "Test", timeLimitMinutes: 0,
            frequencyType: .weeklyN, weeklyCount: 2,
            assignedWeekdays: [], sortOrder: 0
        )

        // Act
        let result = habit.effectiveWeekdays

        // Assert — defaults for count 2: Sun(1), Sat(7)
        XCTAssertEqual(result, [1, 7])
    }
}
