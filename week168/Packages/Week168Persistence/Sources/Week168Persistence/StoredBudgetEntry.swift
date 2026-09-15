import Foundation
import SwiftData
import Week168Domain

@Model
final class StoredBudgetEntry {
    var activityID: UUID = UUID()
    var year: Int = 1970
    var month: Int = 1
    var day: Int = 1
    var direction: String = "cap"
    var wishMinutes: Int = 0
    var committedMinutes: Int? = nil

    init(_ value: BudgetEntry) {
        update(value)
    }

    func update(_ value: BudgetEntry) {
        activityID = value.activityID.rawValue
        year = value.effectiveFrom.startDay.year
        month = value.effectiveFrom.startDay.month
        day = value.effectiveFrom.startDay.day
        direction = value.direction.rawValue
        wishMinutes = value.wishMinutes
        committedMinutes = value.committedMinutes
    }

    func domainValue() throws -> BudgetEntry {
        BudgetEntry(
            activityID: ActivityID(rawValue: activityID),
            effectiveFrom: LogicalWeek(startDay: LogicalDay(year: year, month: month, day: day)),
            direction: try decodedDirection(),
            wishMinutes: wishMinutes,
            committedMinutes: committedMinutes
        )
    }

    private func decodedDirection() throws -> BudgetDirection {
        guard let value = BudgetDirection(rawValue: direction) else {
            throw PersistenceError.invalidStoredValue(direction)
        }
        return value
    }
}
