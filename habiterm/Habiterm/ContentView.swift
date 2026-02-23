import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }

            WeeklyCalendarView()
                .tabItem {
                    Label("Weekly", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    ContentView()
}
