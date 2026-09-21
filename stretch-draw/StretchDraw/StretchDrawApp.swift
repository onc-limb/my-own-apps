import SwiftData
import SwiftUI

@main
struct StretchDrawApp: App {
    private let container: ModelContainer
    private let startupErrorMessage: String?

    init() {
        let schema = Schema([DailyDraw.self])
        let isTesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            startupErrorMessage = nil
        } catch {
            startupErrorMessage = error.localizedDescription
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                preconditionFailure("Failed to create model container: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if startupErrorMessage == nil {
                RootView()
            } else {
                DataStoreUnavailableView()
            }
        }
        .modelContainer(container)
    }
}

private struct DataStoreUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "記録を読み込めませんでした",
            systemImage: "externaldrive.badge.xmark",
            description: Text("端末を再起動してから、もう一度Stretch Drawを開いてください。記録は自動的に削除されません。")
        )
    }
}
