import SwiftData
@testable import Habiterm

enum ModelContainerHelper {
    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([Habit.self, CompletionRecord.self])
        return try ModelContainer(for: schema, configurations: [config])
    }
}
