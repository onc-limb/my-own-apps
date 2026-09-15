import Foundation
import Week168UseCases

final class FakeClock: Week168UseCases.Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var instant: Date

    init(_ instant: Date) { self.instant = instant }
    func now() -> Date { lock.withLock { instant } }
    func advance(minutes: Int) { lock.withLock { instant.addTimeInterval(Double(minutes) * 60) } }
}
