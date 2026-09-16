import SwiftUI

enum AppTab: Hashable { case home, allocation, activities, records, settings }

struct ContentView: View {
    let model: HomeViewModel
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(model: model) { selection = .allocation }
            }
            .tabItem { Label("tab.home", systemImage: "house") }.tag(AppTab.home)
            placeholder("tab.allocation", symbol: "chart.pie", tab: .allocation)
            placeholder("tab.activities", symbol: "square.grid.2x2", tab: .activities)
            placeholder("tab.records", symbol: "list.bullet.rectangle", tab: .records)
            placeholder("tab.settings", symbol: "gearshape", tab: .settings)
        }
        .onChange(of: selection) { _, _ in model.dismissUndo() }
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
