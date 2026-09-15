import Foundation

public struct SystemClock: Clock {
    public init() {}
    // ASSUMPTION: Only this boundary reads wall time; use cases receive it through Clock.
    public func now() -> Date { Date.now }
}
