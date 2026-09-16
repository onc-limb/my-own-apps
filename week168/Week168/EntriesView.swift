import SwiftUI
import Week168Domain

struct EntriesView: View {
    @Bindable var model: ActivitiesEntriesViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var editor: EntryEditorRoute?
    @State private var deletion: TimeEntry?

    var body: some View {
        List {
            ManagementIssue(model: model)
            if model.daySections.isEmpty && !model.isBusy {
                ContentUnavailableView("entries.empty", systemImage: "list.bullet.rectangle",
                                       description: Text("entries.emptyHint"))
            }
            ForEach(model.daySections) { section in
                Section(model.dayTitle(section.day)) {
                    ForEach(section.entries) { entry in
                        Button {
                            model.issue = nil
                            editor = EntryEditorRoute(entry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(model.name(entry.activityID)).font(.headline)
                                Text(model.timestamp(entry.startedAt)).font(.callout)
                                if let end = entry.endedAt {
                                    Text(managementText("entries.endDisplay", model.timestamp(end))).font(.callout)
                                } else {
                                    Label("entries.running", systemImage: "record.circle").font(.callout)
                                }
                                if !entry.note.isEmpty { Text(entry.note).font(.body).foregroundStyle(.secondary) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(AccessibilityPresentation.text("a11y.editEntry", model.name(entry.activityID)))
                        .accessibilityValue([model.timestamp(entry.startedAt),
                            entry.endedAt.map { managementText("entries.endDisplay", model.timestamp($0)) }
                                ?? String(localized: "entries.running"), entry.note].joined(separator: ", "))
                        .contextMenu {
                            Button("action.edit") { model.issue = nil; editor = EntryEditorRoute(entry: entry) }
                                .accessibilityLabel(AccessibilityPresentation.text("a11y.editEntry", model.name(entry.activityID)))
                            Button("action.delete", role: .destructive) { deletion = entry }
                                .accessibilityLabel(AccessibilityPresentation.text("a11y.deleteEntry", model.name(entry.activityID), model.timestamp(entry.startedAt)))
                        }
                        .swipeActions {
                            Button("action.delete", role: .destructive) { deletion = entry }
                                .accessibilityLabel(AccessibilityPresentation.text("a11y.deleteEntry", model.name(entry.activityID), model.timestamp(entry.startedAt)))
                        }
                    }
                }
            }
            .disabled(model.isBusy)
        }
        .navigationTitle("tab.records")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("entries.add", systemImage: "plus") {
                    model.issue = nil
                    editor = EntryEditorRoute(entry: nil)
                }.disabled(model.isBusy || model.settings == nil)
            }
        }
        .sheet(item: $editor) { route in
            NavigationStack { EntryEditor(model: model, original: route.entry) }
        }
        .confirmationDialog("entries.deleteTitle", isPresented: Binding(
            get: { deletion != nil }, set: { if !$0 { deletion = nil } }
        ), titleVisibility: .visible, presenting: deletion) { entry in
            Button("action.delete", role: .destructive) { Task { await model.deleteEntry(entry) } }
            Button("action.cancel", role: .cancel) {}
        } message: { entry in
            Text(managementText("entries.deleteMessage", model.name(entry.activityID), model.timestamp(entry.startedAt)))
        }
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && editor == nil { Task { await model.refresh() } }
        }
    }
}

private struct EntryEditorRoute: Identifiable {
    let id = UUID()
    let entry: TimeEntry?
}

private struct EntryEditor: View {
    @Bindable var model: ActivitiesEntriesViewModel
    let original: TimeEntry?
    @Environment(\.dismiss) private var dismiss
    @State private var activity: ActivityID?
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnd: Bool
    @State private var note: String
    @State private var confirmingDelete = false

    init(model: ActivitiesEntriesViewModel, original: TimeEntry?) {
        self.model = model
        self.original = original
        let now = Date.now
        _activity = State(initialValue: original?.activityID)
        // ASSUMPTION: A new manual entry starts with the previous 30 minutes, requiring an activity choice.
        _start = State(initialValue: original?.startedAt ?? now.addingTimeInterval(-30 * 60))
        _end = State(initialValue: original?.endedAt ?? now)
        _hasEnd = State(initialValue: original == nil || original?.endedAt != nil)
        _note = State(initialValue: original?.note ?? "")
    }

    var body: some View {
        Form {
            if model.activities.isEmpty { Text("entries.noActivities") }
            Section("entries.details") {
                AccessiblePicker("entries.activity", selection: $activity) {
                    Text("entries.selectActivity").tag(Optional<ActivityID>.none)
                    ForEach(model.activities) { item in
                        // Archived activities remain available for historical manual records.
                        Text(item.isArchived ? managementText("entries.archivedActivity", model.path(item)) : model.path(item))
                            .tag(Optional(item.id))
                    }
                }
                AccessibleDatePicker("entries.start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                if original != nil && original?.endedAt == nil {
                    Label("entries.running", systemImage: "record.circle")
                    Toggle("entries.setEnd", isOn: $hasEnd)
                }
                if hasEnd {
                    AccessibleDatePicker("entries.end", selection: $end, displayedComponents: [.date, .hourAndMinute])
                }
                TextField("entries.note", text: $note, axis: .vertical)
            }
            ManagementIssue(model: model)
            if original != nil {
                Section {
                    Button("action.delete", role: .destructive) { confirmingDelete = true }
                }
            }
        }
        .environment(\.timeZone, model.timeZone)
        .navigationTitle(LocalizedStringKey(original == nil ? "entries.add" : "entries.edit"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel") { dismiss() }.disabled(model.isBusy)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("action.save") {
                    Task {
                        if await model.saveEntry(original: original, activity: activity, start: start,
                                                 end: hasEnd ? end : nil, note: note) { dismiss() }
                    }
                }.disabled(model.isBusy || activity == nil)
                .accessibilityLabel(Text("a11y.saveEntry"))
            }
        }
        .confirmationDialog("entries.deleteTitle", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("action.delete", role: .destructive) {
                if let original {
                    Task {
                        await model.deleteEntry(original)
                        if model.issue == nil { dismiss() }
                    }
                }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .disabled(model.isBusy)
        .interactiveDismissDisabled(model.isBusy)
    }
}
