import SwiftData
import XCTest
@testable import TimeBranch

final class TimeBranchTests: XCTestCase {
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WorkProject.self, DisplayPage.self, TimeEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    func testSwitchingProjectStopsCurrentAndStartsNextAtSameInstant() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = WorkProject(name: "First")
        let second = WorkProject(name: "Second")
        context.insert(first)
        context.insert(second)

        let start = Date(timeIntervalSince1970: 1_000)
        let switched = Date(timeIntervalSince1970: 1_300)
        try TimerService.toggle(project: first, at: start, in: context)
        try TimerService.toggle(project: second, at: switched, in: context)

        let entries = try context.fetch(FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.startedAt)]))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].endedAt, switched)
        XCTAssertEqual(entries[1].startedAt, switched)
        XCTAssertNil(entries[1].endedAt)
    }

    @MainActor
    func testTappingActiveProjectStopsIt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let project = WorkProject(name: "Project")
        context.insert(project)
        let start = Date(timeIntervalSince1970: 2_000)
        let end = Date(timeIntervalSince1970: 2_120)

        try TimerService.toggle(project: project, at: start, in: context)
        try TimerService.toggle(project: project, at: end, in: context)

        XCTAssertNil(try TimerService.activeEntry(in: context))
        XCTAssertEqual(try XCTUnwrap(project.entries.first).duration(), 120, accuracy: 0.001)
    }

    @MainActor
    func testChildEntriesRollUpToParentWithoutGapWhenSwitchingSiblings() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let parent = WorkProject(name: "Parent")
        let childA = WorkProject(name: "A", parent: parent)
        let childB = WorkProject(name: "B", parent: parent)
        context.insert(parent)
        context.insert(childA)
        context.insert(childB)

        let start = Date(timeIntervalSince1970: 10_000)
        let middle = Date(timeIntervalSince1970: 10_100)
        let end = Date(timeIntervalSince1970: 10_300)
        context.insert(TimeEntry(project: childA, startedAt: start, endedAt: middle))
        context.insert(TimeEntry(project: childB, startedAt: middle, endedAt: end))

        let interval = DateInterval(start: start, end: end)
        let entries = try context.fetch(FetchDescriptor<TimeEntry>())
        let totals = ReportService.totals(
            projects: [parent, childA, childB],
            entries: entries,
            interval: interval,
            now: end
        )

        XCTAssertEqual(totals.first(where: { $0.project.id == parent.id })?.seconds, 300)
        XCTAssertEqual(totals.first(where: { $0.project.id == childA.id })?.seconds, 100)
        XCTAssertEqual(totals.first(where: { $0.project.id == childB.id })?.seconds, 200)
    }
}
