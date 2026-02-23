import SwiftUI
import SwiftData

@main
struct HabitermApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Habit.self, CompletionRecord.self])
    }
}
