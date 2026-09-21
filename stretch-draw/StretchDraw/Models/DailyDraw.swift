import Foundation
import SwiftData

@Model
final class DailyDraw {
    var id: UUID
    var drawnAt: Date
    var stretchID: String
    var rarityRawValue: String
    var rerollCount: Int
    var completed: Bool
    var completedAt: Date?

    init(
        stretch: Stretch,
        drawnAt: Date = .now,
        rerollCount: Int = 0,
        completed: Bool = false
    ) {
        id = UUID()
        self.drawnAt = drawnAt
        stretchID = stretch.id
        rarityRawValue = stretch.rarity.rawValue
        self.rerollCount = rerollCount
        self.completed = completed
    }

    var canReroll: Bool {
        rerollCount < 1 && !completed
    }

    func replace(with stretch: Stretch) {
        guard canReroll else { return }
        stretchID = stretch.id
        rarityRawValue = stretch.rarity.rawValue
        rerollCount += 1
    }

    func complete(at date: Date = .now) {
        completed = true
        completedAt = date
    }
}
