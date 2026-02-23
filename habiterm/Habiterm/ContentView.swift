import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }

            Text("Coming Soon")
                .font(.title2)
                .foregroundStyle(.secondary)
                .tabItem {
                    Label("Weekly", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    ContentView()
}
