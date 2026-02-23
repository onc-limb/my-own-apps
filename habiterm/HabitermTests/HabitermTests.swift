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
}
