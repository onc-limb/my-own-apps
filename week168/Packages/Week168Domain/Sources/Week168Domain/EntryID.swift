import Foundation

public struct EntryID: Sendable, Hashable, Codable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
