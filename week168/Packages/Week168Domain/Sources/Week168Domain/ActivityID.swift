import Foundation

public struct ActivityID: Sendable, Hashable, Codable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
