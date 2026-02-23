import SwiftUI
import SwiftData

@main
struct HabitermApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await NotificationService.shared.requestAuthorization()
                }
        }
        .modelContainer(for: [Habit.self, CompletionRecord.self])
    }
}
