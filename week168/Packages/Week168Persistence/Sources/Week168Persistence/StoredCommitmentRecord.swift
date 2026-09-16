import Foundation
import SwiftData
import Week168Domain

@Model
final class StoredCommitmentRecord {
    var year: Int = 1970
    var month: Int = 1
    var day: Int = 1
    var committedAt: Date = Date(timeIntervalSince1970: 0)

    init(_ record: CommitmentRecord) {
        year = record.week.startDay.year
        month = record.week.startDay.month
        day = record.week.startDay.day
        committedAt = record.committedAt
    }

    func domainValue() -> CommitmentRecord {
        CommitmentRecord(week: LogicalWeek(startDay: LogicalDay(year: year, month: month, day: day)),
                         committedAt: committedAt)
    }
}
