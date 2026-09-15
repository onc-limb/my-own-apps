import Foundation
import SwiftData
import Week168Domain

@Model
final class StoredTimeEntry {
    var id: UUID = UUID()
    var activityID: UUID = UUID()
    var startedAt: Date = Date(timeIntervalSince1970: 0)
    var endedAt: Date? = nil
    var plannedMinutes: Int? = nil
    var note: String = ""

    init(_ value: TimeEntry) {
        update(value)
    }

    func update(_ value: TimeEntry) {
        id = value.id.rawValue
        activityID = value.activityID.rawValue
        startedAt = value.startedAt
        endedAt = value.endedAt
        plannedMinutes = value.plannedMinutes
        note = value.note
    }

    func domainValue() -> TimeEntry {
        TimeEntry(
            id: EntryID(rawValue: id),
            activityID: ActivityID(rawValue: activityID),
            startedAt: startedAt,
            endedAt: endedAt,
            plannedMinutes: plannedMinutes,
            note: note
        )
    }
}
