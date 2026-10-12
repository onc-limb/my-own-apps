import XCTest
@testable import StretchGacha

/// テスト専用の手動クロック（アプリターゲットには置かない）。
final class TestTimerClock: TimerClock, @unchecked Sendable {
    private var current: Double = 0
    func advance(by seconds: Double) { current += seconds }
    func nowSeconds() -> Double { current }
}

final class SpyFeedback: CompletionFeedback, @unchecked Sendable {
    private(set) var successCount = 0
    func notifySuccess() { successCount += 1 }
}

final class SpyRecorder: PracticeRecording, @unchecked Sendable {
    private(set) var completions: [(itemID: String, completedAt: Date)] = []
    func recordCompletion(itemID: String, completedAt: Date) {
        completions.append((itemID, completedAt))
    }
}

@MainActor
final class StretchTimerTests: XCTestCase {

    private func item(duration: Int) -> StretchItem {
        StretchItem(id: "neck-02", name: "首の横倒し", kind: .stretch, bodyPart: .neck,
                    rarity: .n, durationSeconds: duration, emoji: "🙆",
                    steps: ["手順1", "手順2"], caution: nil)
    }

    private func makeViewModel(duration: Int = 60)
        -> (StretchTimerViewModel, TestTimerClock, SpyFeedback, SpyRecorder, () -> Bool) {
        let clock = TestTimerClock()
        let feedback = SpyFeedback()
        let recorder = SpyRecorder()
        var idleDisabled = false
        let vm = StretchTimerViewModel(item: item(duration: duration),
                                       clock: clock,
                                       feedback: feedback,
                                       recorder: recorder,
                                       now: { Date(timeIntervalSince1970: 1_755_500_000) },
                                       setIdleTimerDisabled: { idleDisabled = $0 })
        return (vm, clock, feedback, recorder, { idleDisabled })
    }

    // MARK: - TimerEngine（純粋関数）

    func testDurationClamps() {
        XCTAssertEqual(TimerEngine.duration(for: item(duration: 60)), 60)
        XCTAssertEqual(TimerEngine.duration(for: item(duration: 0)), 1)
        XCTAssertEqual(TimerEngine.duration(for: item(duration: -10)), 1)
        XCTAssertEqual(TimerEngine.duration(for: item(duration: 9999)), 600)
    }

    func testDisplaySecondsCeiling() {
        XCTAssertEqual(TimerEngine.displaySeconds(remaining: 60.0), 60)
        XCTAssertEqual(TimerEngine.displaySeconds(remaining: 59.4), 60)
        XCTAssertEqual(TimerEngine.displaySeconds(remaining: 59.0), 59)
        XCTAssertEqual(TimerEngine.displaySeconds(remaining: 0.1), 1)
        XCTAssertEqual(TimerEngine.displaySeconds(remaining: 0.0), 0)
    }

    func testProgress() {
        XCTAssertEqual(TimerEngine.progress(remaining: 60.0, duration: 60), 0.0)
        XCTAssertEqual(TimerEngine.progress(remaining: 30.0, duration: 60), 0.5)
        XCTAssertEqual(TimerEngine.progress(remaining: 0.0, duration: 60), 1.0)
        XCTAssertEqual(TimerEngine.progress(remaining: 10.0, duration: 0), 1.0)  // ゼロ除算ガード
    }

    func testRemainingNeverGoesNegative() {
        XCTAssertEqual(TimerEngine.remaining(deadline: 10, now: 25), 0)
        XCTAssertEqual(TimerEngine.remaining(deadline: 25, now: 10), 15)
    }

    // MARK: - 状態機械

    func testCountdownWithInjectedClock() {
        let (vm, clock, _, _, _) = makeViewModel(duration: 60)
        clock.advance(by: 30.0)
        vm.tick()
        XCTAssertEqual(vm.remaining, 30.0, accuracy: 0.0001)
        XCTAssertEqual(vm.displaySeconds, 30)
        XCTAssertEqual(vm.progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(vm.phase, .running)
    }

    func testFinishesExactlyAtDuration() {
        let (vm, clock, _, _, _) = makeViewModel(duration: 60)
        clock.advance(by: 59.9)
        vm.tick()
        XCTAssertEqual(vm.phase, .running)
        clock.advance(by: 0.1)
        vm.tick()
        XCTAssertEqual(vm.phase, .finished)
    }

    func testCompletionSideEffectsFireExactlyOnce() {
        let (vm, clock, feedback, recorder, _) = makeViewModel(duration: 60)
        clock.advance(by: 60)
        vm.tick()
        vm.tick()
        vm.tick()
        XCTAssertEqual(feedback.successCount, 1)
        XCTAssertEqual(recorder.completions.count, 1)
        XCTAssertEqual(recorder.completions[0].itemID, "neck-02")
    }

    func testAbortRecordsNothing() {
        let (vm, clock, feedback, recorder, idleDisabled) = makeViewModel(duration: 60)
        clock.advance(by: 10)
        vm.tick()
        vm.abort()
        XCTAssertEqual(feedback.successCount, 0)
        XCTAssertEqual(recorder.completions.count, 0)
        XCTAssertFalse(idleDisabled())
    }

    func testPausePreservesRemainingRegardlessOfElapsedTime() {
        let (vm, clock, _, _, _) = makeViewModel(duration: 60)
        clock.advance(by: 20)
        vm.tick()
        vm.pause()
        clock.advance(by: 300)   // バックグラウンドに 5 分
        vm.tick()                // paused 中の tick は無視される
        XCTAssertEqual(vm.remaining, 40.0, accuracy: 0.0001)
        vm.resume()
        vm.tick()
        XCTAssertEqual(vm.remaining, 40.0, accuracy: 0.0001)
        XCTAssertEqual(vm.phase, .running)
    }

    func testResumeWhileRunningIsIgnored() {
        let (vm, clock, _, _, _) = makeViewModel(duration: 60)
        clock.advance(by: 10)
        vm.tick()
        let before = vm.remaining
        vm.resume()
        vm.tick()
        XCTAssertEqual(vm.remaining, before, accuracy: 0.0001)
        XCTAssertEqual(vm.phase, .running)
    }

    func testFinishedIsTerminal() {
        let (vm, clock, feedback, recorder, _) = makeViewModel(duration: 60)
        clock.advance(by: 60)
        vm.tick()
        vm.pause()
        vm.resume()
        vm.tick()
        XCTAssertEqual(vm.phase, .finished)
        XCTAssertEqual(feedback.successCount, 1)
        XCTAssertEqual(recorder.completions.count, 1)
    }

    // MARK: - 自動ロック抑止

    func testIdleTimerDisabledOnlyWhileRunning() {
        let (vm, clock, _, _, idleDisabled) = makeViewModel(duration: 60)
        XCTAssertTrue(idleDisabled())    // init 直後 = running
        vm.pause()
        XCTAssertFalse(idleDisabled())
        vm.resume()
        XCTAssertTrue(idleDisabled())
        clock.advance(by: 60)
        vm.tick()
        XCTAssertFalse(idleDisabled())   // finished で解除
    }

    func testOnDisappearAlwaysReleasesIdleTimer() {
        let (vm, _, _, _, idleDisabled) = makeViewModel(duration: 60)
        XCTAssertTrue(idleDisabled())
        vm.onDisappear()
        XCTAssertFalse(idleDisabled())
    }

    // MARK: - 性能

    func testEngineComputation100kWithin2Seconds() {
        let start = Date()
        for i in 0..<100_000 {
            let remaining = TimerEngine.remaining(deadline: 60, now: Double(i % 60))
            _ = TimerEngine.displaySeconds(remaining: remaining)
            _ = TimerEngine.progress(remaining: remaining, duration: 60)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    // カタログ側の運用ルール: 前後半で対象が切り替わる種目は
    // 「残り◯秒」の指示を持ち、指示秒数が durationSeconds / 2 と一致する
    func testCatalogSwitchInstructionsMatchHalfDuration() {
        let switchItemIDs = ["neck-02", "neck-05", "shoulder-02", "shoulder-03", "shoulder-04",
                             "shoulder-05", "lowback-02", "lowback-03", "upperback-04",
                             "legs-01", "legs-02", "legs-03", "eyeswrist-01"]
        for id in switchItemIDs {
            guard let item = StretchCatalog.shared.item(id: id) else {
                XCTFail("種目が見つからない: \(id)")
                continue
            }
            let expected = "残り\(item.durationSeconds / 2)秒"
            XCTAssertTrue(item.steps.contains { $0.contains(expected) },
                          "\(id): 「\(expected)」の切り替え指示が無い")
        }
    }
}
