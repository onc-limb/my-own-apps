import SwiftUI

enum AppTab: Hashable { case home, allocation, activities, records, settings }

struct ContentView: View {
    let model: HomeViewModel
    let allocationModel: AllocationViewModel
    let managementModel: ActivitiesEntriesViewModel
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
            placeholder("tab.settings", symbol: "gearshape", tab: .settings)
        }
        .onChange(of: selection) { _, tab in
            model.dismissUndo()
            if tab == .home { Task { await model.refresh() } }
            if tab == .allocation { Task { await allocationModel.refresh() } }
            if tab == .activities || tab == .records { Task { await managementModel.refresh() } }
        }
    }

    private func placeholder(_ title: LocalizedStringKey, symbol: String, tab: AppTab) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: symbol)
            } description: {
                Text("placeholder.description")
            }
            .navigationTitle(title)
        }
        .tabItem { Label(title, systemImage: symbol) }
        .tag(tab)
    }
}
