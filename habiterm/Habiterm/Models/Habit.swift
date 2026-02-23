import Foundation
import SwiftData

@Model
final class Habit {
    var name: String
    var timeLimitMinutes: Int
    var frequencyType: FrequencyType
    var weeklyCount: Int  // daily の場合は 7 として統一
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)
    var completionRecords: [CompletionRecord] = []

    init(name: String, timeLimitMinutes: Int, frequencyType: FrequencyType, weeklyCount: Int, sortOrder: Int, createdAt: Date = .now) {
        self.name = name
        self.timeLimitMinutes = timeLimitMinutes
        self.frequencyType = frequencyType
        self.weeklyCount = frequencyType == .daily ? 7 : weeklyCount
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
