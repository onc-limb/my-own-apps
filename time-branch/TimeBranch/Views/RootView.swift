import SwiftUI

struct RootView: View {
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
        }
    }
}

