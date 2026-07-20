import SwiftUI

struct RootView: View {
    @Binding var languageCode: String

    var body: some View {
        TabView {
            NavigationStack {
                TimerView()
            }
            .tabItem { Label("計測", systemImage: "timer") }

            NavigationStack {
                ReportsView()
            }
            .tabItem { Label("レポート", systemImage: "chart.bar.xaxis") }

            NavigationStack {
                ProjectManagementView()
            }
            .tabItem { Label("プロジェクト", systemImage: "folder") }

            NavigationStack {
                SettingsView(languageCode: $languageCode)
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
    }
}
