import Foundation

public enum EntryValidator {
    /// existing は重なりうる期間に絞ってよい。編集中の同一 ID は除外する。
    public static func validate(_ candidate: TimeEntry, against existing: [TimeEntry], now: Date) throws {
        // ASSUMPTION: 複数違反時は未来、前後関係、進行中の重複、時間帯の重なりの順で報告する。
        guard candidate.startedAt <= now, candidate.endedAt.map({ $0 <= now }) ?? true else {
            throw EntryValidationError.inFuture
        }
        if let end = candidate.endedAt {
            guard end >= candidate.startedAt else { throw EntryValidationError.endBeforeStart }
            guard end > candidate.startedAt else { throw EntryValidationError.zeroLength }
        }

        let others = existing.filter { $0.id != candidate.id }
        if candidate.endedAt == nil, let running = others.first(where: { $0.endedAt == nil }) {
            throw EntryValidationError.anotherEntryRunning(running.id)
        }

        let end = candidate.endedAt ?? now
        let overlapping = others.filter { entry in
            let otherEnd = entry.endedAt ?? now
            // 空の半開区間 [now, now) はどの記録とも重ならない。
            return candidate.startedAt < end && entry.startedAt < otherEnd
                && candidate.startedAt < otherEnd && entry.startedAt < end
        }
        if !overlapping.isEmpty {
            // ASSUMPTION: 重なった相手は existing の入力順で全件返す。
            throw EntryValidationError.overlaps(with: overlapping.map(\.id))
        }
    }
}
