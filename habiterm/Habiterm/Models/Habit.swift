import Foundation
import SwiftData

@Model
final class Habit {
    var name: String
    var timeLimitMinutes: Int  // 0 = タイマー不要
    var frequencyType: FrequencyType
    var weeklyCount: Int  // daily の場合は 7 として統一
    var assignedWeekdays: [Int] = []  // 1=日曜, 2=月曜, ..., 7=土曜 (Calendar準拠)。空配列=全曜日表示
    var sortOrder: Int
    var createdAt: Date
    var isActive: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)
    var completionRecords: [CompletionRecord] = []

    var effectiveWeekdays: [Int] {
        if assignedWeekdays.isEmpty && frequencyType == .weeklyN {
            return CalendarHelper.defaultWeekdays(for: weeklyCount)
        }
        return assignedWeekdays
    }

    init(name: String, timeLimitMinutes: Int, frequencyType: FrequencyType, weeklyCount: Int, assignedWeekdays: [Int] = [], sortOrder: Int, createdAt: Date = .now, isActive: Bool = true) {
        self.name = name
        self.timeLimitMinutes = timeLimitMinutes
        self.frequencyType = frequencyType
        self.weeklyCount = frequencyType == .daily ? 7 : weeklyCount
        self.assignedWeekdays = frequencyType == .daily ? [] : assignedWeekdays
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
