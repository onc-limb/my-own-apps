import SwiftData
import SwiftUI

@main
struct TimeBranchApp: App {
    private let container: ModelContainer
    private let startupErrorMessage: String?
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.japanese.rawValue

    init() {
        let processInfo = ProcessInfo.processInfo
        let isTesting = processInfo.arguments.contains("--uitesting")
        if isTesting, let initialLanguage = processInfo.environment["UITEST_INITIAL_LANGUAGE"] {
            UserDefaults.standard.set(initialLanguage, forKey: AppLanguage.storageKey)
        }

        let schema = Schema([
            WorkProject.self,
            DisplayPage.self,
            TimeEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTesting)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            startupErrorMessage = nil
        } catch {
            startupErrorMessage = error.localizedDescription
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                preconditionFailure("Failed to create fallback model container: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if startupErrorMessage == nil {
                    RootView(languageCode: $languageCode)
                } else {
                    DataStoreUnavailableView()
                }
            }
            .environment(\.locale, selectedLanguage.locale)
        }
        .modelContainer(container)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .japanese
    }
}

private struct DataStoreUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "データを読み込めませんでした",
            systemImage: "externaldrive.badge.xmark",
            description: Text("端末を再起動してから、もう一度TimeBranchを開いてください。改善しない場合はサポートへ連絡してください。データは自動的に削除されません。")
        )
    }
}
