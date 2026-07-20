import Foundation

enum TimeEntryValidationError: LocalizedError, Equatable {
    case invalidRange
    case futureEndDate
    case overlapsExistingEntry

    var errorDescription: String? {
        switch self {
        case .invalidRange:
            return "終了時刻は開始時刻より後にしてください。"
        case .futureEndDate:
            return "未来の終了時刻は指定できません。"
        case .overlapsExistingEntry:
            return "別の時間記録と重複しています。"
        }
    }
}

enum TimeEntryValidationService {
    static func validate(
        startedAt: Date,
        endedAt: Date,
        excluding entryID: UUID? = nil,
        entries: [TimeEntry],
        now: Date = .now
    ) throws {
        guard endedAt > startedAt else {
            throw TimeEntryValidationError.invalidRange
        }
        guard endedAt <= now else {
            throw TimeEntryValidationError.futureEndDate
        }

        let overlaps = entries.contains { entry in
            guard entry.id != entryID else { return false }
            let existingEnd = entry.endedAt ?? .distantFuture
            return entry.startedAt < endedAt && existingEnd > startedAt
        }

        guard !overlaps else {
            throw TimeEntryValidationError.overlapsExistingEntry
        }
    }
}
