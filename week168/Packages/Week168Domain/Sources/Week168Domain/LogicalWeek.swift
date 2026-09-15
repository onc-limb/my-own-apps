import Foundation

public struct LogicalWeek: Sendable, Hashable, Comparable {
    public let startDay: LogicalDay

    public init(startDay: LogicalDay) {
        self.startDay = startDay
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.startDay < rhs.startDay
    }
}
