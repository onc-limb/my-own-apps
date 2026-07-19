import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var note: String
    var project: WorkProject?

    init(project: WorkProject, startedAt: Date = .now, endedAt: Date? = nil, note: String = "") {
        id = UUID()
        self.project = project
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
    }

    func duration(until now: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }

    func overlappingDuration(from rangeStart: Date, to rangeEnd: Date, now: Date = .now) -> TimeInterval {
        let effectiveEnd = endedAt ?? now
        let overlapStart = max(startedAt, rangeStart)
        let overlapEnd = min(effectiveEnd, rangeEnd)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }
}

