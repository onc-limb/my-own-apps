import Foundation
import Testing
import Week168Domain
import Week168Persistence
import Week168UseCases

struct RestoreTests {
    @Test func restorePreservesCommittedReportAndRefreshesRunningAlarms() async throws {
        let f = try RestoreFixture()
        _ = try await f.service.homeSections(recentLimit: 8)
        let activity = try await f.service.createActivity(name: "Goal", budgetMode: .managed, defaultPlannedMinutes: 90)
        try await f.service.setWish(activityID: activity.id, minutes: 120, direction: .goal, week: f.week)
        try await f.service.commitAllocation(week: f.week, committed: [activity.id: 120])
        _ = try await f.service.startOrSwitch(to: activity.id)
        let original = try await f.store.backup()
        let report = try await f.service.weeklyReport(for: f.week)
        let root: [String: Any] = ["schemaVersion": 1, "app": ["name": "Week168", "version": "1", "build": "1"],
            "exportedAt": BackupJSON.timestamp(f.clock.now()), "period": ["from": "2026-09-14", "to": "2026-09-20"],
            "summary": NSNull(), "data": BackupJSON.rawObject(original)]
        let replacement = try BackupJSON.decode(JSONSerialization.data(withJSONObject: root), now: f.clock.now())
        try await f.service.uncommitAllocation(week: f.week)
        await f.alarms.reset()
        try await f.service.restore(replacement, replacing: f.store.backup())
        let allocation = try await f.service.allocationReport(for: f.week)
        #expect(allocation.state == .committed)
        #expect(try await f.service.weeklyReport(for: f.week) == report)
        #expect(try await f.store.backup() == original)
        #expect(await f.alarms.cancelled.contains(original.entries[0].id))
        #expect(await f.alarms.planned.contains { $0.entryID == original.entries[0].id })
    }

    @Test func staleRestoreDoesNotCancelRunningAlarms() async throws {
        let f = try RestoreFixture()
        _ = try await f.service.homeSections(recentLimit: 8)
        let activity = try await f.service.createActivity(name: "Running")
        let old = try await f.store.backup()
        _ = try await f.service.startOrSwitch(to: activity.id)
        let fresh = try await f.store.backup()
        await f.alarms.reset()
        await #expect(throws: BackupError.staleConfirmation) {
            try await f.service.restore(old, replacing: old)
        }
        #expect(try await f.store.backup() == fresh)
        #expect(await f.alarms.cancelled.isEmpty)
    }
}

private final class RestoreFixture: Sendable {
    let store: Week168Store
    let service: Week168Service
    let clock = FakeClock(ISO8601DateFormatter().date(from: "2026-09-15T12:00:00Z")!)
    let alarms = RecordingAlarms()
    let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))
    init() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = Week168Store(container: try Week168Store.makeContainer(at: directory.appendingPathComponent("restore.store")))
        service = Week168Service(store: store, clock: clock, alarms: alarms)
        // No directory deletion while store/container can still be alive.
    }
}
