import SwiftData
import SwiftUI

@main
struct TimeBranchApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([
            WorkProject.self,
            DisplayPage.self,
            TimeEntry.self
        ])
        let isTesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
