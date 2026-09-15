import Foundation

public struct TimeEntry: Sendable, Equatable, Identifiable {
    public let id: EntryID
    public var activityID: ActivityID
    public var startedAt: Date
    /// nil は進行中。
    public var endedAt: Date?
    /// nil は予定なし（アラームを鳴らさない）。
    public var plannedMinutes: Int?
    public var note: String

    public init(
        id: EntryID, activityID: ActivityID, startedAt: Date, endedAt: Date?,
        plannedMinutes: Int?, note: String
    ) {
        self.id = id
        self.activityID = activityID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedMinutes = plannedMinutes
        self.note = note
    }
}
