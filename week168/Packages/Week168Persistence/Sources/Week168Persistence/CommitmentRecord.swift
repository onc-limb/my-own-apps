import Foundation
import Week168Domain

public struct CommitmentRecord: Sendable, Equatable {
    public let week: LogicalWeek
    public let committedAt: Date

    public init(week: LogicalWeek, committedAt: Date) {
        self.week = week
        self.committedAt = committedAt
    }
}
