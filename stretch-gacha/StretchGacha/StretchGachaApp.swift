import SwiftUI
import SwiftData

@main
struct StretchGachaApp: App {
    private let container: ModelContainer
    private let practiceStore: PracticeStore

    init() {
        do {
            // iCloud 同期は有効化しない（記録を端末外へ複製しない）
            container = try ModelContainer(for: DailyDrawState.self, PracticeRecord.self)
        } catch {
            fatalError("ModelContainer の初期化に失敗: \(error)")
        }
        practiceStore = PracticeStore(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            SafetyNoticeGateView {
                RootTabView()
                    .environment(practiceStore)
            }
        }
        .modelContainer(container)
    }
}
