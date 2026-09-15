import Foundation
import Testing
import Week168Domain

@Suite("計測記録")
struct TimeEntryTests {
    private func id(_ value: Int) -> EntryID {
        EntryID(rawValue: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!)
    }

    private func activityID(_ value: Int) -> ActivityID {
        ActivityID(rawValue: id(value).rawValue)
    }

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        Date(timeIntervalSince1970: TimeInterval(hour * 3600 + minute * 60))
    }

    private func entry(_ value: Int, from start: Date, to end: Date? = nil) -> TimeEntry {
        TimeEntry(id: id(value), activityID: activityID(1), startedAt: start, endedAt: end,
                  plannedMinutes: 60, note: "Original note")
    }

    private var existing: TimeEntry { entry(1, from: time(10), to: time(11)) }
    private var running: TimeEntry { entry(1, from: time(10)) }

    private func switched(at instant: Date? = nil, plannedMinutes: Int? = 30) -> SwitchResult {
        EntrySwitcher.switchActivity(running: running, to: activityID(2),
            plannedMinutes: plannedMinutes, at: instant ?? time(11), newID: id(2))
    }

    @Test("01: 部分的な重なりは相手の ID を報告する")
    func partialOverlap() {
        #expect(throws: EntryValidationError.overlaps(with: [id(1)])) {
            try EntryValidator.validate(entry(2, from: time(10, 30), to: time(11, 30)),
                                        against: [existing], now: time(12))
        }
    }

    @Test("02: 既存記録の直前に隣接できる")
    func adjacentBefore() throws {
        try EntryValidator.validate(entry(2, from: time(9), to: time(10)), against: [existing], now: time(12))
    }

    @Test("03: 既存記録の直後に隣接できる")
    func adjacentAfter() throws {
        try EntryValidator.validate(entry(2, from: time(11), to: time(12)), against: [existing], now: time(12))
    }

    @Test("04: 既存記録を完全に覆うと重なる")
    func enclosingOverlap() {
        #expect(throws: EntryValidationError.overlaps(with: [id(1)])) {
            try EntryValidator.validate(entry(2, from: time(9), to: time(12)), against: [existing], now: time(12))
        }
    }

    @Test("05: 既存記録の内側も重なる")
    func enclosedOverlap() {
        #expect(throws: EntryValidationError.overlaps(with: [id(1)])) {
            try EntryValidator.validate(entry(2, from: time(10, 15), to: time(10, 45)),
                                        against: [existing], now: time(12))
        }
    }

    @Test("06: 重なった相手を全件報告し重ならない相手は含めない")
    func allOverlappingEntries() {
        let entries = [existing, entry(3, from: time(11), to: time(12)),
                       entry(4, from: time(8), to: time(9))]
        #expect(throws: EntryValidationError.overlaps(with: [id(1), id(3)])) {
            try EntryValidator.validate(entry(2, from: time(10, 30), to: time(11, 30)),
                                        against: entries, now: time(12))
        }
    }

    @Test("07: 進行中は現在時刻までを占める")
    func overlapWithRunning() {
        #expect(throws: EntryValidationError.overlaps(with: [id(1)])) {
            try EntryValidator.validate(entry(2, from: time(11), to: time(11, 30)),
                                        against: [running], now: time(12))
        }
    }

    @Test("08: 進行中の直前に隣接できる")
    func adjacentToRunning() throws {
        try EntryValidator.validate(entry(2, from: time(9), to: time(10)), against: [running], now: time(12))
    }

    @Test("09: 編集で自分自身とは重ならない")
    func editingExcludesSelf() throws {
        var edited = existing
        edited.endedAt = time(11, 30)
        try EntryValidator.validate(edited, against: [existing], now: time(12))
    }

    @Test("10: 別の進行中の記録を保存できない")
    func anotherRunningEntry() {
        #expect(throws: EntryValidationError.anotherEntryRunning(id(1))) {
            try EntryValidator.validate(entry(2, from: time(11)), against: [running], now: time(12))
        }
    }

    @Test("11: 進行中があっても重ならない過去の記録は保存できる")
    func pastEntryWhileRunning() throws {
        try EntryValidator.validate(entry(2, from: time(8), to: time(9)), against: [running], now: time(12))
    }

    @Test("12: 終了が開始より前なら拒否する")
    func endBeforeStart() {
        #expect(throws: EntryValidationError.endBeforeStart) {
            try EntryValidator.validate(entry(1, from: time(11), to: time(10)), against: [], now: time(12))
        }
    }

    @Test("13: 長さゼロの手入力を拒否する")
    func zeroLength() {
        #expect(throws: EntryValidationError.zeroLength) {
            try EntryValidator.validate(entry(1, from: time(10), to: time(10)), against: [], now: time(12))
        }
    }

    @Test("14: 開始が未来なら拒否する")
    func futureStart() {
        #expect(throws: EntryValidationError.inFuture) {
            try EntryValidator.validate(entry(1, from: time(13), to: time(14)), against: [], now: time(12))
        }
    }

    @Test("15: 終了が未来なら拒否する")
    func futureEnd() {
        #expect(throws: EntryValidationError.inFuture) {
            try EntryValidator.validate(entry(1, from: time(11), to: time(13)), against: [], now: time(12))
        }
    }

    @Test("16: 終了が現在時刻ちょうどなら保存できる")
    func endAtNow() throws {
        try EntryValidator.validate(entry(1, from: time(11), to: time(12)), against: [], now: time(12))
    }

    @Test("17: 進行中も開始が未来なら拒否する")
    func futureRunningStart() {
        #expect(throws: EntryValidationError.inFuture) {
            try EntryValidator.validate(entry(1, from: time(13)), against: [], now: time(12))
        }
    }

    @Test("18: 切り替えの終了と開始はタップ時刻に一致する")
    func exactSwitchInstant() throws {
        let result = switched()
        let closed = try #require(result.closed)
        #expect(result.previousRunning == running)
        var expectedClosed = running
        expectedClosed.endedAt = time(11)
        #expect(closed == expectedClosed)
        #expect(result.started.startedAt == time(11))
        #expect(closed.endedAt == result.started.startedAt)
        #expect(result.started.id == id(2))
        #expect(result.started.activityID == activityID(2))
        #expect(result.started.endedAt == nil)
        #expect(result.started.note == "")
    }

    @Test("19: 切り替えた二つの記録は重ならない")
    func switchedEntriesValidate() throws {
        let result = switched()
        let closed = try #require(result.closed)
        try EntryValidator.validate(closed, against: [result.started], now: time(12))
        try EntryValidator.validate(result.started, against: [closed], now: time(12))
    }

    @Test("20: 開始と同時の切り替えは前の記録を破棄する")
    func discardZeroDurationSwitch() {
        let result = switched(at: time(10))
        #expect(result.closed == nil)
        #expect(result.started.startedAt == time(10))
        #expect(result.started.endedAt == nil)
        #expect(result.started.id == id(2))
        #expect(result.started.activityID == activityID(2))
    }

    @Test("21: 進行中がなくても新規開始できる")
    func startWithoutRunning() {
        let result = EntrySwitcher.switchActivity(running: nil, to: activityID(2),
            plannedMinutes: 30, at: time(11), newID: id(2))
        #expect(result.closed == nil)
        #expect(result.started == TimeEntry(id: id(2), activityID: activityID(2),
            startedAt: time(11), endedAt: nil, plannedMinutes: 30, note: ""))
    }

    @Test("22: 切り替え先の予定時間を引き継ぐ")
    func plannedDuration() {
        #expect(switched(plannedMinutes: 45).started.plannedMinutes == 45)
    }

    @Test("23: 予定なしは nil を維持する")
    func noPlannedDuration() {
        #expect(switched(plannedMinutes: nil).started.plannedMinutes == nil)
    }

    @Test("24: 取り消すと元の開始時刻のまま進行中に戻る")
    func undoReopensEntry() throws {
        let restored = try #require(EntrySwitcher.undo(switched()))
        #expect(restored.endedAt == nil)
        #expect(restored.startedAt == time(10))
        #expect(restored.activityID == activityID(1))
    }

    @Test("25: 同じ瞬間の切り替えを取り消すと元の活動が進行中に戻る")
    func undoSameInstantSwitch() throws {
        let result = switched(at: time(10))
        #expect(result.closed == nil)
        #expect(result.previousRunning == running)
        let restored = try #require(EntrySwitcher.undo(result))
        #expect(restored == running)
        #expect(restored.endedAt == nil)
    }

    @Test("26: 取り消しは元の ID・開始・予定時間・メモを保持する")
    func undoPreservesOriginal() throws {
        let restored = try #require(EntrySwitcher.undo(switched()))
        #expect(restored.id == running.id)
        #expect(restored.startedAt == running.startedAt)
        #expect(restored.plannedMinutes == running.plannedMinutes)
        #expect(restored.note == running.note)
        #expect(restored == running)
    }

    @Test("進行中の編集も同一 ID を除外する")
    func editingRunningExcludesSelf() throws {
        var edited = running
        edited.note = "Edited note"
        try EntryValidator.validate(edited, against: [running], now: time(12))
    }

    @Test("編集時も他の記録との重なりは拒否する")
    func editingStillChecksOthers() {
        var edited = existing
        edited.endedAt = time(11, 30)
        #expect(throws: EntryValidationError.overlaps(with: [id(2)])) {
            try EntryValidator.validate(edited,
                against: [existing, entry(2, from: time(11), to: time(12))], now: time(12))
        }
    }

    @Test("進行中の候補も現在時刻までの重なりを調べる")
    func runningCandidateOverlap() {
        #expect(throws: EntryValidationError.overlaps(with: [id(1)])) {
            try EntryValidator.validate(entry(2, from: time(10, 30)), against: [existing], now: time(12))
        }
    }

    @Test("現在時刻に開始した進行中の空区間は重ならない")
    func emptyRunningInterval() throws {
        let completed = entry(1, from: time(10), to: time(12))
        let started = entry(2, from: time(12))
        try EntryValidator.validate(started, against: [completed], now: time(12))
        try EntryValidator.validate(completed, against: [started], now: time(12))
    }

    @Test("F-1: 時計が巻き戻っても切り替えでき、取り消しは元の記録を復元する")
    func clockRollbackSwitch() {
        let result = switched(at: time(9))
        #expect(result.closed == nil)
        #expect(result.started.startedAt == time(9))
        #expect(result.started.endedAt == nil)
        #expect(result.started.id == id(2))
        #expect(result.started.activityID == activityID(2))
        #expect(result.previousRunning == running)
        #expect(EntrySwitcher.undo(result) == running)
    }

    @Test("F-2: 進行中がない状態で切り替えてから取り消すと nil")
    func undoInitialStart() {
        let result = EntrySwitcher.switchActivity(running: nil, to: activityID(2),
            plannedMinutes: nil, at: time(11), newID: id(2))
        #expect(result.previousRunning == nil)
        #expect(result.closed == nil)
        #expect(EntrySwitcher.undo(result) == nil)
    }
}
