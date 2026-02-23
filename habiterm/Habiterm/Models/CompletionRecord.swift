import Foundation
import SwiftData

@Model
final class CompletionRecord {
    var completedAt: Date
    var durationSeconds: Int
    var habit: Habit?

    init(completedAt: Date = .now, durationSeconds: Int, habit: Habit) {
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.habit = habit
    }
}
