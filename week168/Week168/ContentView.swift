import SwiftUI

enum AppTab: Hashable { case home, allocation, activities, records, review }

struct ContentView: View {
    let model: HomeViewModel
    let allocationModel: AllocationViewModel
    let managementModel: ActivitiesEntriesViewModel
    let reviewModel: ReviewViewModel
    let settingsModel: SettingsViewModel
    @State private var selection: AppTab = .home
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $selection) {
            tabNavigation {
                HomeView(model: model) { selection = .allocation }
            }
            .tabItem { Label("tab.home", systemImage: "house") }.tag(AppTab.home)
            tabNavigation { AllocationView(model: allocationModel) }
                .tabItem { Label("tab.allocation", systemImage: "chart.pie") }.tag(AppTab.allocation)
            tabNavigation { ActivitiesView(model: managementModel) }
                .tabItem { Label("tab.activities", systemImage: "square.grid.2x2") }.tag(AppTab.activities)
            tabNavigation { EntriesView(model: managementModel) }
                .tabItem { Label("tab.records", systemImage: "list.bullet.rectangle") }.tag(AppTab.records)
            tabNavigation { ReviewView(model: reviewModel) }
                .tabItem { Label("tab.review", systemImage: "chart.bar") }.tag(AppTab.review)
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            Task {
                switch selection {
                case .home: await model.refresh()
                case .allocation: await allocationModel.refresh()
                case .activities, .records: await managementModel.refresh()
                case .review: await reviewModel.refresh()
                }
            }
        }) {
            NavigationStack {
                SettingsView(model: settingsModel)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("action.close") { showingSettings = false }
                                .accessibilityIdentifier("settings.close")
                        }
                    }
            }
        }
        .onChange(of: selection) { _, tab in
            model.dismissUndo()
            if tab == .review { Task { await reviewModel.refresh() } }
            if tab == .home { Task { await model.refresh() } }
            if tab == .allocation { Task { await allocationModel.refresh() } }
            if tab == .activities || tab == .records { Task { await managementModel.refresh() } }
        }
    }

    private func tabNavigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            model.dismissUndo()
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(Text("tab.settings"))
                        .accessibilityIdentifier("settings.open")
                    }
                }
        }
    }
}
