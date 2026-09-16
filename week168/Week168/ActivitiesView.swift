import SwiftUI
import Week168Domain

struct ActivitiesView: View {
    @Bindable var model: ActivitiesEntriesViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var editor: ActivityEditorRoute?

    var body: some View {
        List {
            ManagementIssue(model: model)
            if model.activities.isEmpty && !model.isBusy {
                ContentUnavailableView("activities.empty", systemImage: "square.grid.2x2",
                                       description: Text("activities.emptyHint"))
            }
            ForEach(model.activities) { activity in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        model.issue = nil
                        editor = ActivityEditorRoute(activity: activity)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(ActivityColor.color(activity.colorHex))
                                    .accessibilityHidden(true)
                                Text(activity.name).font(.headline).foregroundStyle(.primary)
                            }
                            if activity.parentID != nil {
                                Text(model.path(activity)).font(.caption).foregroundStyle(.secondary)
                            }
                            BudgetModeBadge(choice: ActivityBudgetChoice(activity.budgetMode))
                            if activity.isArchived {
                                Label("activities.archived", systemImage: "archivebox")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Menu {
                        Button("action.edit") { model.issue = nil; editor = ActivityEditorRoute(activity: activity) }
                        Button(LocalizedStringKey(activity.isArchived ? "activities.unarchive" : "activities.archive")) {
                            Task { await model.archive(activity) }
                        }
                        Button("activities.moveUp", systemImage: "arrow.up") {
                            Task { await model.move(activity, offset: -1) }
                        }.disabled(!model.canMove(activity, offset: -1))
                        Button("activities.moveDown", systemImage: "arrow.down") {
                            Task { await model.move(activity, offset: 1) }
                        }.disabled(!model.canMove(activity, offset: 1))
                        Button("action.delete", role: .destructive) {
                            Task { await model.prepareDeletion(activity) }
                        }
                    } label: {
                        Label("activities.actions", systemImage: "ellipsis.circle")
                    }
                }
                // ASSUMPTION: Cap visual indentation to preserve readable text at arbitrary depth;
                // the complete ancestor path above still identifies every level.
                .padding(.leading, CGFloat(min(model.tree?.ancestors(of: activity.id).count ?? 0, 4)) * 12)
            }
            .disabled(model.isBusy)
        }
        .navigationTitle("tab.activities")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("activities.add", systemImage: "plus") {
                    model.issue = nil
                    editor = ActivityEditorRoute(activity: nil)
                }.disabled(model.isBusy || model.tree == nil)
            }
        }
        .sheet(item: $editor) { route in
            NavigationStack { ActivityEditor(model: model, original: route.activity) }
        }
        .confirmationDialog("activities.deleteTitle", isPresented: Binding(
            get: { model.deletion != nil }, set: { if !$0 { model.deletion = nil } }
        ), titleVisibility: .visible, presenting: model.deletion) { preview in
            Button("action.delete", role: .destructive) { Task { await model.deleteActivity(preview) } }
            Button("action.cancel", role: .cancel) {}
        } message: { preview in Text(preview.message) }
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && editor == nil { Task { await model.refresh() } }
        }
    }
}

private struct ActivityEditorRoute: Identifiable {
    let id = UUID()
    let activity: Activity?
}

private struct ActivityEditor: View {
    @Bindable var model: ActivitiesEntriesViewModel
    let original: Activity?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var parent: ActivityID?
    @State private var budget: ActivityBudgetChoice
    @State private var minutes: String
    @State private var color: String

    init(model: ActivitiesEntriesViewModel, original: Activity?) {
        self.model = model
        self.original = original
        _name = State(initialValue: original?.name ?? "")
        _parent = State(initialValue: original?.parentID)
        _budget = State(initialValue: ActivityBudgetChoice(original?.budgetMode ?? .unset))
        _minutes = State(initialValue: original?.defaultPlannedMinutes.map(String.init) ?? "")
        _color = State(initialValue: original?.colorHex ?? "")
    }

    private var validation: String? {
        model.activityValidation(name: name, parent: parent, mode: budget.mode, minutes: minutes, editing: original?.id)
    }

    var body: some View {
        Form {
            Section("activities.details") {
                TextField("activities.name", text: $name)
                if original == nil {
                    Picker("activities.parent", selection: $parent) {
                        Text("activities.noParent").tag(Optional<ActivityID>.none)
                        ForEach(model.activities) { activity in
                            Text(model.path(activity)).tag(Optional(activity.id))
                        }
                    }
                } else {
                    LabeledContent("activities.parent") {
                        Text(parent.flatMap { model.tree?.node($0) }.map { model.path($0) }
                             ?? String(localized: "activities.noParent"))
                    }
                    Text("activities.parentFixed").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("activities.budgetMode") {
                Picker("activities.budgetMode", selection: $budget) {
                    ForEach(ActivityBudgetChoice.allCases) { choice in
                        Text(LocalizedStringKey(choice.titleKey)).tag(choice)
                    }
                }
                ForEach(ActivityBudgetChoice.allCases) { choice in
                    VStack(alignment: .leading, spacing: 6) {
                        BudgetModeBadge(choice: choice)
                        Text(LocalizedStringKey(choice.explanationKey)).font(.callout)
                    }
                }
            }
            Section {
                TextField("activities.defaultMinutes", text: $minutes).keyboardType(.numberPad)
            } header: {
                Text("activities.defaultPlan")
            } footer: {
                Text("activities.defaultPlanHint")
            }
            Section("activities.color") {
                Picker("activities.color", selection: $color) {
                    ForEach(ActivityColor.options, id: \.hex) { option in
                        Label {
                            Text(LocalizedStringKey(option.key))
                        } icon: {
                            Image(systemName: "circle.fill").foregroundStyle(ActivityColor.color(option.hex))
                        }.tag(option.hex)
                    }
                    if !ActivityColor.options.contains(where: { $0.hex == color }) {
                        Text("activities.color.existing").tag(color)
                    }
                }
            }
            if let validation {
                Label(validation, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            ManagementIssue(model: model)
        }
        .navigationTitle(LocalizedStringKey(original == nil ? "activities.add" : "activities.edit"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel") { dismiss() }.disabled(model.isBusy)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("action.save") {
                    Task {
                        if await model.saveActivity(original: original, name: name, parent: parent,
                                                    mode: budget.mode, minutes: minutes, color: color) { dismiss() }
                    }
                }.disabled(validation != nil || model.isBusy)
            }
        }
        .disabled(model.isBusy)
        .interactiveDismissDisabled(model.isBusy)
    }
}

enum ActivityBudgetChoice: String, CaseIterable, Identifiable {
    case managed, unset, excluded
    var id: String { rawValue }
    init(_ mode: BudgetMode) {
        switch mode {
        case .managed: self = .managed
        case .unset: self = .unset
        case .excluded: self = .excluded
        }
    }
    var mode: BudgetMode {
        switch self {
        case .managed: .managed
        case .unset: .unset
        case .excluded: .excluded
        }
    }
    var titleKey: String { "activities.mode.\(rawValue)" }
    var explanationKey: String { "activities.mode.\(rawValue).hint" }
    var symbol: String {
        switch self {
        case .managed: "checkmark.circle.fill"
        case .unset: "questionmark.circle"
        case .excluded: "nosign"
        }
    }
}

struct BudgetModeBadge: View {
    let choice: ActivityBudgetChoice
    var body: some View {
        Label(LocalizedStringKey(choice.titleKey), systemImage: choice.symbol)
            .font(.caption)
            .padding(6)
            .background(choice == .excluded ? Color.secondary.opacity(0.16) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: choice == .unset ? [4, 3] : []))
                    .foregroundStyle(.secondary)
            }
    }
}

enum ActivityColor {
    // ASSUMPTION: Offer a named palette; retain an existing custom color until explicitly changed.
    static let options: [(hex: String, key: String)] = [
        ("", "activities.color.default"), ("#3478F6", "activities.color.blue"),
        ("#34A853", "activities.color.green"), ("#F29900", "activities.color.orange"),
        ("#AF52DE", "activities.color.purple"), ("#E84563", "activities.color.red")
    ]
    static func color(_ hex: String) -> Color {
        guard hex.hasPrefix("#"), hex.count == 7, let value = UInt32(hex.dropFirst(), radix: 16) else { return .accentColor }
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

struct ManagementIssue: View {
    let model: ActivitiesEntriesViewModel
    var body: some View {
        if let issue = model.issue {
            VStack(alignment: .leading, spacing: 8) {
                Label(issue, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                Button("action.retry") { Task { await model.refresh() } }.disabled(model.isBusy)
            }
        }
    }
}
