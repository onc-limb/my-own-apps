/// その週の配分の確定状態。
public enum CommitmentState: Sendable, Equatable {
    case unused
    case pending
    case committed
}

public extension AllocationReport {
    func commitmentState(hasCommitmentRecord: Bool) -> CommitmentState {
        guard nodes.contains(where: { $0.mode == .managed }) else {
            return .unused
        }
        return hasCommitmentRecord && canCommit ? .committed : .pending
    }
}
