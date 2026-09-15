import Foundation
import SwiftData
import Week168Domain

@Model
final class StoredCapacityEntry {
    var year: Int = 1970
    var month: Int = 1
    var day: Int = 1
    var totalMinutes: Int? = nil

    init(_ value: CapacityEntry) {
        update(value)
    }

    func update(_ value: CapacityEntry) {
        year = value.effectiveFrom.startDay.year
        month = value.effectiveFrom.startDay.month
        day = value.effectiveFrom.startDay.day
        totalMinutes = value.totalMinutes
    }

    func domainValue() -> CapacityEntry {
        CapacityEntry(
            effectiveFrom: LogicalWeek(startDay: LogicalDay(year: year, month: month, day: day)),
            totalMinutes: totalMinutes
        )
    }
}
