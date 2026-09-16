import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    @Environment(\.notifications) private var notifications
    @State private var importing = false

    var body: some View {
        Form {
            if let notifications {
                Section {
                    Text(LocalizedStringKey(notifications.isAuthorized ? "notifications.allowed" : "notifications.notAllowed"))
                    if !notifications.isAuthorized { OpenNotificationSettingsButton() }
                    if let issue = notifications.issueKey {
                        Label(LocalizedStringKey(issue), systemImage: "exclamationmark.triangle")
                    }
                }
            }
            Section("settings.capacity") {
                TextField("settings.capacityMinutes", text: $model.capacity).keyboardType(.numberPad)
                Text("settings.capacityHint").font(.footnote)
                Button("settings.saveCapacity") { Task { await model.saveCapacity() } }
            }
            Section("settings.calendar") {
                Picker("settings.dayStart", selection: $model.dayStartHour) {
                    ForEach(0...6, id: \.self) { hour in Text(reviewText("settings.hour", hour)).tag(hour) }
                }
                Picker("settings.weekStart", selection: $model.weekStartWeekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(LocalizedStringKey("settings.weekday.\(day)")).tag(day)
                    }
                }
                Picker("settings.timeZone", selection: $model.timeZoneIdentifier) {
                    ForEach(Array(Set(TimeZone.knownTimeZoneIdentifiers + [model.timeZoneIdentifier])).sorted(), id: \.self) { zone in
                        Text(zone).tag(zone)
                    }
                }
                Text("settings.calendarHint").font(.footnote)
                Button("settings.saveCalendar") { Task { await model.saveCalendar() } }
            }
            Section("settings.backup") {
                Toggle("settings.allTime", isOn: $model.allTime)
                if !model.allTime {
                    DatePicker("settings.from", selection: $model.from, displayedComponents: .date)
                    DatePicker("settings.to", selection: $model.to, displayedComponents: .date)
                }
                Text("settings.exportHint").font(.footnote)
                Button("settings.export", systemImage: "square.and.arrow.up") { Task { await model.export() } }
                Button("settings.import", systemImage: "square.and.arrow.down") { importing = true }
            }
            if model.isBusy { ProgressView("home.loading") }
            if let notice = model.notice { Text(notice).accessibilityAddTraits(.updatesFrequently) }
            if let issue = model.issue {
                Section {
                    Text(issue)
                    Button("action.retry") { Task { await model.refresh() } }
                }
            }
        }
        .disabled(model.isBusy)
        .environment(\.timeZone, model.settings.flatMap { TimeZone(identifier: $0.timeZoneIdentifier) } ?? .current)
        .navigationTitle("tab.settings")
        .task { await model.refresh() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): Task { await model.prepareImport(url) }
            case .failure: model.issue = String(localized: "settings.error.import")
            }
        }
        .alert("settings.restoreTitle", isPresented: Binding(
            get: { model.restorePreview != nil }, set: { if !$0 { model.restorePreview = nil } }
        ), presenting: model.restorePreview) { preview in
            Button("settings.restoreConfirm", role: .destructive) { Task { await model.restore(preview) } }
            Button("action.cancel", role: .cancel) { model.restorePreview = nil }
        } message: { preview in Text(preview.message) }
        .sheet(item: $model.sharedBackup, onDismiss: { model.clearSharedFile() }) { backup in
            BackupShareSheet(url: backup.url)
        }
    }
}

private struct BackupShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
