import Foundation
import SwiftData

@Observable
final class HabitFormViewModel {

    // MARK: - Form Properties

    var name: String = ""
    var timeLimitMinutes: Int = 25
    var frequencyType: FrequencyType = .daily
    var weeklyCount: Int = 7

    // MARK: - State

    var isEditing: Bool { editingHabit != nil }

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let editingHabit: Habit?

    // MARK: - Init

    init(modelContext: ModelContext, habit: Habit? = nil) {
        self.modelContext = modelContext
        self.editingHabit = habit

        if let habit {
            self.name = habit.name
            self.timeLimitMinutes = habit.timeLimitMinutes
            self.frequencyType = habit.frequencyType
            self.weeklyCount = habit.weeklyCount
        }
    }

    // MARK: - Actions

    /// Saves the habit. Creates a new one or updates the existing one.
    func save() throws {
        if let habit = editingHabit {
            // Update existing
            habit.name = name
            habit.timeLimitMinutes = timeLimitMinutes
            habit.frequencyType = frequencyType
            habit.weeklyCount = frequencyType == .daily ? 7 : weeklyCount
        } else {
            // Create new
            let maxSortOrder = try fetchMaxSortOrder()
            let newHabit = Habit(
                name: name,
                timeLimitMinutes: timeLimitMinutes,
                frequencyType: frequencyType,
                weeklyCount: frequencyType == .daily ? 7 : weeklyCount,
                sortOrder: maxSortOrder + 1,
                createdAt: Date()
            )
            modelContext.insert(newHabit)
        }
    }

    /// Deletes the habit being edited.
    func delete() {
        guard let habit = editingHabit else { return }
        modelContext.delete(habit)
    }

    // MARK: - Private Helpers

    private func fetchMaxSortOrder() throws -> Int {
        var descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let results = try modelContext.fetch(descriptor)
        return results.first?.sortOrder ?? 0
    }
}
