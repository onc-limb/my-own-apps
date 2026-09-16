import Foundation
import Observation
import SwiftData
import SwiftUI
import Week168Domain
import Week168Persistence
import Week168UseCases

// ASSUMPTION: T-13 supplies notification delivery; connect the service protocol now.
private struct PlaceholderAlarmScheduler: AlarmScheduling {
    func schedulePlannedTimeAlarm(entryID: EntryID, activityName: String, fireAt: Date) async {}
    func scheduleBudgetExhaustionNotice(activityID: ActivityID, activityName: String, fireAt: Date) async {}
    func cancelAll(for entryID: EntryID) async {}
}

@MainActor @Observable
private final class AppDependencies {
    private(set) var container: ModelContainer?
    private(set) var home: HomeViewModel?
    private(set) var allocation: AllocationViewModel?
    private(set) var management: ActivitiesEntriesViewModel?

    init() { open() }

    func open() {
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Week168", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let container = try Week168Store.makeContainer(at: directory.appendingPathComponent("Week168.store"))
            let store = Week168Store(container: container)
            let service = Week168Service(store: store, clock: SystemClock(), alarms: PlaceholderAlarmScheduler())
            self.container = container
            home = HomeViewModel(store: store, service: service)
            allocation = AllocationViewModel(store: store, service: service)
            management = ActivitiesEntriesViewModel(store: store, service: service)
        } catch {
            // Keep the localized recovery screen visible; never replace persisted data with an empty store.
            home = nil
            allocation = nil
            management = nil
        }
    }
}

@main
@MainActor
struct Week168App: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            if let home = dependencies.home, let allocation = dependencies.allocation,
               let management = dependencies.management {
                ContentView(model: home, allocationModel: allocation, managementModel: management)
            } else {
                ContentUnavailableView {
                    Label("error.title", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("error.storage")
                } actions: {
                    Button("action.retry") { dependencies.open() }
                }
            }
        }
    }
}
