import XCTest
@testable import Week168

final class Week168Tests: XCTestCase {
    @MainActor
    func testAppCanBeCreated() {
        _ = Week168App()
    }
}

import UserNotifications
import Week168Domain
import SwiftData
@testable import Week168Persistence
import Week168UseCases

@MainActor
private final class NotificationCenterSpy: NotificationCenterClient {
    var status: UNAuthorizationStatus
    var grantsPermission = true
    var authorizationRequests = 0
    var pending: [String: UNNotificationRequest] = [:]
    var maximumBudgetCount = 0
    var failsToAdd = false

    init(status: UNAuthorizationStatus = .authorized) { self.status = status }
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        status = grantsPermission ? .authorized : .denied
        return grantsPermission
    }
    func add(_ request: UNNotificationRequest) async throws {
        if failsToAdd { throw CocoaError(.fileWriteUnknown) }
        pending[request.identifier] = request
        maximumBudgetCount = max(maximumBudgetCount, pending.keys.filter { $0 == "budget-notice" }.count)
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers { pending.removeValue(forKey: identifier) }
    }
}

@MainActor
final class NotificationAlarmSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let entryID = EntryID(rawValue: UUID())
    private let activityID = ActivityID(rawValue: UUID())

    private func scheduler(_ center: NotificationCenterSpy) -> NotificationAlarmScheduler {
        let date = now
        return NotificationAlarmScheduler(center: center, now: { date })
    }
    private func planned(_ scheduler: NotificationAlarmScheduler, at date: Date? = nil) async {
        await scheduler.schedulePlannedTimeAlarm(entryID: entryID, activityName: "Activity", fireAt: date ?? now.addingTimeInterval(60))
    }
    private func budget(_ scheduler: NotificationAlarmScheduler, id: ActivityID? = nil) async {
        await scheduler.scheduleBudgetExhaustionNotice(activityID: id ?? activityID, activityName: "Activity", fireAt: now.addingTimeInterval(120))
    }
    private func entry(planned: Int?, ended: Bool = false) -> TimeEntry {
        TimeEntry(id: entryID, activityID: activityID, startedAt: now, endedAt: ended ? now : nil, plannedMinutes: planned, note: "")
    }

    func testPlannedAlarmUsesEntryIdentifierAndSound() async throws {
        let center = NotificationCenterSpy()
        await planned(scheduler(center))
        XCTAssertEqual(center.pending.count, 1)
        let request = try XCTUnwrap(center.pending["planned-\(entryID.rawValue.uuidString)"])
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, 60)
        XCTAssertFalse(trigger.repeats)
        XCTAssertNotNil(request.content.sound)
    }

    func testBudgetNoticeUsesFixedIdentifier() async {
        let center = NotificationCenterSpy()
        await budget(scheduler(center))
        XCTAssertEqual(Array(center.pending.keys), ["budget-notice"])
    }

    func testCancelRemovesBothNotifications() async {
        let center = NotificationCenterSpy()
        let scheduler = scheduler(center)
        await planned(scheduler)
        await budget(scheduler)
        await scheduler.cancelAll(for: entryID)
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testSwitchingNeverLeavesMoreThanOneBudgetNotice() async {
        let center = NotificationCenterSpy()
        let scheduler = scheduler(center)
        await planned(scheduler)
        await budget(scheduler)
        await scheduler.cancelAll(for: entryID)
        let next = EntryID(rawValue: UUID())
        await scheduler.schedulePlannedTimeAlarm(entryID: next, activityName: "Next", fireAt: now.addingTimeInterval(60))
        await budget(scheduler, id: ActivityID(rawValue: UUID()))
        // Even a replacement before cancellation still occupies the same OS request identifier.
        await budget(scheduler, id: ActivityID(rawValue: UUID()))
        XCTAssertEqual(center.maximumBudgetCount, 1)
        XCTAssertEqual(center.pending.count, 2)
        await scheduler.cancelAll(for: next)
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testDeniedAuthorizationDoesNotRegisterOrThrow() async {
        let center = NotificationCenterSpy(status: .denied)
        let scheduler = scheduler(center)
        await planned(scheduler)
        await budget(scheduler)
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertEqual(center.authorizationRequests, 0)
        XCTAssertNil(scheduler.issueKey)
    }

    func testPastAndCurrentDatesAreNotScheduled() async {
        let center = NotificationCenterSpy(status: .notDetermined)
        let scheduler = scheduler(center)
        await planned(scheduler, at: now.addingTimeInterval(-1))
        await planned(scheduler, at: now)
        await scheduler.scheduleBudgetExhaustionNotice(activityID: activityID, activityName: "Past", fireAt: now.addingTimeInterval(-1))
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertEqual(center.authorizationRequests, 0)
    }

    func testFirstReservationRequestsPermissionButInitializationDoesNot() async {
        let center = NotificationCenterSpy(status: .notDetermined)
        let scheduler = scheduler(center)
        await scheduler.refreshAuthorizationStatus()
        XCTAssertEqual(center.authorizationRequests, 0)
        await planned(scheduler)
        await budget(scheduler)
        XCTAssertEqual(center.authorizationRequests, 1)
        XCTAssertEqual(center.pending.count, 2)
        XCTAssertTrue(scheduler.isAuthorized)
    }

    func testUndeterminedLifecycleRefreshNeitherPromptsNorSchedules() async {
        let center = NotificationCenterSpy(status: .notDetermined)
        let scheduler = scheduler(center)
        await scheduler.suppressingAuthorizationRequest {
            await self.planned(scheduler)
            await self.budget(scheduler)
        }
        XCTAssertEqual(center.authorizationRequests, 0)
        XCTAssertTrue(center.pending.isEmpty)
        await planned(scheduler)
        XCTAssertEqual(center.authorizationRequests, 1)
    }

    func testAuthorizedLifecycleRefreshSchedulesNormally() async {
        let center = NotificationCenterSpy()
        let scheduler = scheduler(center)
        await scheduler.suppressingAuthorizationRequest {
            await self.planned(scheduler)
            await self.budget(scheduler)
        }
        XCTAssertEqual(center.authorizationRequests, 0)
        XCTAssertEqual(center.pending.count, 2)
    }

    func testRunningPlannedEntryShowsDeniedWarning() async {
        let scheduler = scheduler(NotificationCenterSpy(status: .denied))
        await scheduler.refreshAuthorizationStatus()
        XCTAssertTrue(scheduler.showsWarning(for: entry(planned: 1)))
    }

    func testRunningUnplannedEntryDoesNotShowDeniedWarning() async {
        let scheduler = scheduler(NotificationCenterSpy(status: .denied))
        await scheduler.refreshAuthorizationStatus()
        XCTAssertFalse(scheduler.showsWarning(for: entry(planned: nil)))
        XCTAssertFalse(scheduler.showsWarning(for: nil))
        XCTAssertFalse(scheduler.showsWarning(for: entry(planned: 1, ended: true)))
    }

    func testAuthorizedEntryDoesNotShowWarningAndSettingsChangesAreReloaded() async {
        let center = NotificationCenterSpy()
        let scheduler = scheduler(center)
        await scheduler.refreshAuthorizationStatus()
        XCTAssertFalse(scheduler.showsWarning(for: entry(planned: 1)))
        center.status = .denied
        await scheduler.refreshAuthorizationStatus()
        XCTAssertTrue(scheduler.showsWarning(for: entry(planned: 1)))
    }

    func testLifecycleSuppressionDoesNotSuppressConcurrentUserOperation() async {
        let center = NotificationCenterSpy(status: .notDetermined)
        let scheduler = scheduler(center)
        let gate = NotificationRefreshGate()
        let refresh = Task {
            await scheduler.suppressingAuthorizationRequest {
                await gate.pause()
                await self.budget(scheduler)
            }
        }
        await gate.waitUntilPaused()
        await planned(scheduler)
        XCTAssertEqual(center.authorizationRequests, 1)
        await gate.resume()
        await refresh.value
        XCTAssertEqual(center.pending.count, 2)
    }

    func testSuppressionIsRestoredAfterFailure() async {
        let center = NotificationCenterSpy(status: .notDetermined)
        let scheduler = scheduler(center)
        do {
            try await scheduler.suppressingAuthorizationRequest { throw CocoaError(.fileReadUnknown) }
            XCTFail("Expected failure")
        } catch {}
        await planned(scheduler)
        XCTAssertEqual(center.authorizationRequests, 1)
    }

    func testSchedulingFailureIsVisibleWithoutThrowing() async {
        let center = NotificationCenterSpy()
        center.failsToAdd = true
        let scheduler = scheduler(center)
        await planned(scheduler)
        XCTAssertEqual(scheduler.issueKey, "notifications.error.schedule")
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testBudgetSuccessDoesNotHidePlannedAlarmFailure() async {
        let center = NotificationCenterSpy()
        let scheduler = scheduler(center)
        center.failsToAdd = true
        await planned(scheduler)
        center.failsToAdd = false
        await budget(scheduler)
        XCTAssertEqual(scheduler.issueKey, "notifications.error.schedule")
        await planned(scheduler)
        XCTAssertNil(scheduler.issueKey)
    }

    func testDecliningFirstPermissionDoesNotSchedule() async {
        let center = NotificationCenterSpy(status: .notDetermined)
        center.grantsPermission = false
        let scheduler = scheduler(center)
        await planned(scheduler)
        XCTAssertFalse(scheduler.isAuthorized)
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertNil(scheduler.issueKey)
    }

    func testDeniedNotificationsAllowStartSwitchAndStop() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = Week168Store(container: try Week168Store.makeContainer(at: directory.appendingPathComponent("store.sqlite")))
        let center = NotificationCenterSpy(status: .denied)
        let service = Week168Service(store: store, clock: SystemClock(), alarms: NotificationAlarmScheduler(center: center))
        let first = try await service.createActivity(name: "First", defaultPlannedMinutes: 60)
        let second = try await service.createActivity(name: "Second", defaultPlannedMinutes: 30)
        _ = try await service.startOrSwitch(to: first.id)
        let runningFirst = try await store.loadRunningEntry()
        XCTAssertEqual(runningFirst?.activityID, first.id)
        _ = try await service.startOrSwitch(to: second.id)
        let runningSecond = try await store.loadRunningEntry()
        XCTAssertEqual(runningSecond?.activityID, second.id)
        try await service.stopRunning()
        let stopped = try await store.loadRunningEntry()
        XCTAssertNil(stopped)
        XCTAssertTrue(center.pending.isEmpty)
    }
}

private actor NotificationRefreshGate {
    private var paused = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func pause() async {
        await withCheckedContinuation {
            continuation = $0
            paused = true
            observer?.resume()
            observer = nil
        }
    }
    func waitUntilPaused() async {
        if !paused { await withCheckedContinuation { observer = $0 } }
    }
    func resume() { continuation?.resume(); continuation = nil }
}

@MainActor
final class SaveFailureViewModelTests: XCTestCase {
    func testStopReportsSaveFailureAndPreservesRunningEntry() async throws {
        let f = try SaveFailureFixture()
        let entry = try await f.runningEntry()
        let model = HomeViewModel(store: f.store, service: f.service)
        await model.refresh()
        await f.store.setSaveFailureForAppTests(true)

        await model.stop()

        XCTAssertEqual(model.issue?.messageKey, "error.saveFailed")
        XCTAssertEqual(model.snapshot?.running, entry)
        let persisted = try await f.store.loadRunningEntry()
        XCTAssertEqual(persisted, entry)
        XCTAssertFalse(model.isBusy)
    }

    func testNonSaveFailureKeepsOperationMessage() async throws {
        let f = try SaveFailureFixture()
        _ = try await f.runningEntry()
        let model = HomeViewModel(store: f.store, service: f.service)
        await model.refresh()

        await model.changePlan(-1)

        XCTAssertEqual(model.issue?.messageKey, "error.plan")
        XCTAssertNotNil(model.snapshot?.running)
    }

    func testSuccessfulStopClearsPreviousSaveFailure() async throws {
        let f = try SaveFailureFixture()
        _ = try await f.runningEntry()
        let model = HomeViewModel(store: f.store, service: f.service)
        await model.refresh()
        await f.store.setSaveFailureForAppTests(true)
        await model.stop()
        XCTAssertEqual(model.issue?.messageKey, "error.saveFailed")
        await f.store.setSaveFailureForAppTests(false)

        await model.stop()

        XCTAssertNil(model.issue)
        XCTAssertNil(model.snapshot?.running)
        let entries = try await f.store.loadEntries(overlapping: DateInterval(start: .distantPast, end: .distantFuture))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.endedAt, f.now)
    }

    func testAllocationSaveFailureKeepsWishUnchanged() async throws {
        let f = try SaveFailureFixture()
        let activity = try await f.service.createActivity(name: "Activity", budgetMode: .managed)
        let model = AllocationViewModel(store: f.store, service: f.service)
        await model.refresh(at: f.now)
        await f.store.setSaveFailureForAppTests(true)

        let saved = await model.saveWish(60, direction: .goal, for: activity.id)

        XCTAssertFalse(saved)
        XCTAssertEqual(model.issueKey, "error.saveFailed")
        let budgets = try await f.store.loadBudgets()
        XCTAssertTrue(budgets.isEmpty)
    }

    func testActivitySaveFailureUsesDedicatedMessage() async throws {
        let f = try SaveFailureFixture()
        _ = try await f.service.homeSections(recentLimit: 8)
        let model = ActivitiesEntriesViewModel(store: f.store, service: f.service)
        await model.refresh()
        await f.store.setSaveFailureForAppTests(true)

        let saved = await model.saveActivity(original: nil, name: "Activity", parent: nil,
                                            mode: .unset, minutes: "", color: "")

        XCTAssertFalse(saved)
        XCTAssertEqual(model.issue, String(localized: "error.saveFailed"))
        XCTAssertTrue(model.activities.isEmpty)
    }

    func testReviewInitializationSaveFailureUsesDedicatedMessage() async throws {
        let f = try SaveFailureFixture()
        await f.store.setSaveFailureForAppTests(true)
        let model = ReviewViewModel(store: f.store, service: f.service)

        await model.refresh(now: f.now)

        XCTAssertEqual(model.issue, String(localized: "error.saveFailed"))
        XCTAssertTrue(model.weeks.isEmpty)
    }

    func testSettingsCalendarAndCapacitySaveFailuresUseDedicatedMessage() async throws {
        let f = try SaveFailureFixture()
        let model = SettingsViewModel(store: f.store, service: f.service)
        await model.refresh(now: f.now)
        await f.store.setSaveFailureForAppTests(true)
        model.dayStartHour = 2

        await model.saveCalendar()

        XCTAssertEqual(model.issue, String(localized: "error.saveFailed"))
        XCTAssertNil(model.notice)
        model.capacity = "600"
        await model.saveCapacity(now: f.now)
        XCTAssertEqual(model.issue, String(localized: "error.saveFailed"))
        XCTAssertNil(model.notice)
    }

    func testOtherPersistenceErrorsKeepFallbackMessage() {
        XCTAssertEqual(AppErrorMessage.key(for: PersistenceError.staleSwitch, fallback: "error.undo"), "error.undo")
        XCTAssertEqual(AppErrorMessage.localized(for: PersistenceError.invalidStoredValue("test"), fallback: "Original"), "Original")
    }
}

@MainActor
private final class SaveFailureFixture {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store: Week168Store
    let service: Week168Service

    init() throws {
        // Match the existing fixtures: CoreData can outlive the test, so retain its temporary directory.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = Week168Store(container: try Week168Store.makeContainer(at: directory.appendingPathComponent("test.store")))
        service = Week168Service(store: store, clock: SaveFailureClock(date: now), alarms: SaveFailureAlarms())
    }

    func runningEntry() async throws -> TimeEntry {
        let activity = try await service.createActivity(name: "Activity")
        let entry = TimeEntry(id: EntryID(rawValue: UUID()), activityID: activity.id,
                              startedAt: now.addingTimeInterval(-60), endedAt: nil, plannedMinutes: nil, note: "")
        try await store.saveEntry(entry, now: now)
        return entry
    }
}

private struct SaveFailureClock: Clock {
    let date: Date
    func now() -> Date { date }
}

private struct SaveFailureAlarms: AlarmScheduling {
    func schedulePlannedTimeAlarm(entryID: EntryID, activityName: String, fireAt: Date) async {}
    func scheduleBudgetExhaustionNotice(activityID: ActivityID, activityName: String, fireAt: Date) async {}
    func cancelAll(for entryID: EntryID) async {}
}

extension Week168Store {
    fileprivate func setSaveFailureForAppTests(_ failing: Bool) {
        saveOperation = { context in
            if failing { throw CocoaError(.fileWriteOutOfSpace) }
            try context.save()
        }
    }
}
