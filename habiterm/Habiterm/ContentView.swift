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

            ManageHabitsView()
                .tabItem {
                    Label("Manage", systemImage: "list.bullet.rectangle")
                }

            BackyardView()
                .tabItem {
                    Label("Backyard", systemImage: "archivebox")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
