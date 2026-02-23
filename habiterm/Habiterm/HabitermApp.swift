import SwiftUI
import SwiftData

@main
struct HabitermApp: App {
    let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await NotificationService.shared.requestAuthorization()
                }
        }
        .modelContainer(for: [Habit.self, CompletionRecord.self],
                        inMemory: isUITesting)
    }
}
