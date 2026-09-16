import SwiftUI

enum AppTab: Hashable { case home, allocation, activities, records, review, settings }

struct ContentView: View {
    let model: HomeViewModel
    let allocationModel: AllocationViewModel
    let managementModel: ActivitiesEntriesViewModel
    let reviewModel: ReviewViewModel
    let settingsModel: SettingsViewModel
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(model: model) { selection = .allocation }
            }
            .tabItem { Label("tab.home", systemImage: "house") }.tag(AppTab.home)
            NavigationStack { AllocationView(model: allocationModel) }
                .tabItem { Label("tab.allocation", systemImage: "chart.pie") }.tag(AppTab.allocation)
            NavigationStack { ActivitiesView(model: managementModel) }
                .tabItem { Label("tab.activities", systemImage: "square.grid.2x2") }.tag(AppTab.activities)
            NavigationStack { EntriesView(model: managementModel) }
                .tabItem { Label("tab.records", systemImage: "list.bullet.rectangle") }.tag(AppTab.records)
            NavigationStack { ReviewView(model: reviewModel) }
                .tabItem { Label("tab.review", systemImage: "chart.bar") }.tag(AppTab.review)
            NavigationStack { SettingsView(model: settingsModel) }
                .tabItem { Label("tab.settings", systemImage: "gearshape") }.tag(AppTab.settings)
        }
        .onChange(of: selection) { _, tab in
            model.dismissUndo()
            if tab == .review { Task { await reviewModel.refresh() } }
            if tab == .settings { Task { await settingsModel.refresh() } }
            if tab == .home { Task { await model.refresh() } }
            if tab == .allocation { Task { await allocationModel.refresh() } }
            if tab == .activities || tab == .records { Task { await managementModel.refresh() } }
        }
    }

}
