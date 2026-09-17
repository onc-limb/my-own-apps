import Foundation
import SwiftUI
import Week168Domain

struct HomeView: View {
    @Bindable var model: HomeViewModel
    let openAllocation: () -> Void
    let openActivityCreation: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.notifications) private var notifications
    @State private var showingPlan = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let logicalWeek = model.snapshot.map {
                TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: context.date, settings: $0.settings), settings: $0.settings)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let snapshot = model.snapshot {
                        let state = snapshot.presentation(at: context.date)
                        if state.commitmentState == .pending { allocationBanner(overflowMinutes: state.capacityOverflowMinutes) }
                        if let result = model.lastSwitch, let expiry = model.undoExpiresAt, context.date < expiry {
                            undoBar(result, snapshot: snapshot)
                        }
                        if let running = snapshot.running {
                            runningCard(running, snapshot: snapshot, state: state, now: context.date)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("home.idle", systemImage: "pause.circle")
                                    .font(.headline)
                                Text("home.tapToStart")
                            }.homeCard()
                            .accessibilityElement(children: .combine)
                        }
                        activitySection("home.goals", ids: state.sections.unmetGoals,
                            empty: state.isCommitted ? "home.noUnmetGoals" : "home.goalsUnavailable",
                            snapshot: snapshot, state: state, hierarchical: false)
                        activitySection("home.recent", ids: state.sections.recentlyUsed,
                            empty: "home.noRecent", snapshot: snapshot, state: state, hierarchical: false)
                        activitySection("home.weekly", ids: state.weekly,
                            empty: "home.noActivities", snapshot: snapshot, state: state, hierarchical: true)
                    } else if model.isBusy {
                        ProgressView("home.loading").frame(maxWidth: .infinity)
                    } else {
                        Text("home.unavailable")
                        Button("action.retry") { Task { await model.refresh() } }
                    }
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: logicalWeek) { oldWeek, newWeek in
                if oldWeek != nil, newWeek != nil { Task { await model.refresh() } }
            }
        }
        .navigationTitle("tab.home")
        .background(Color(uiColor: .systemGroupedBackground))
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .sheet(isPresented: $showingPlan) {
            PlannedMinutesSheet(model: model)
        }
        .alert("error.title", isPresented: Binding(
            get: { !showingPlan && model.issue != nil }, set: { if !$0 { model.issue = nil } }
        )) {
            Button("action.ok", role: .cancel) { model.issue = nil }
        } message: {
            if let issue = model.issue { Text(LocalizedStringKey(issue.messageKey)) }
        }
    }

    private func allocationBanner(overflowMinutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                if overflowMinutes > 0 {
                    Text(String(format: String(localized: "allocation.uncommitted"), HomeTime.minutes(overflowMinutes)))
                } else {
                    Text("allocation.pending")
                }
            } icon: { Image(systemName: "exclamationmark.triangle") }
                .font(.headline)
            Text("allocation.guidance")
            Button("allocation.open") {
                model.dismissUndo()
                openAllocation()
            }
        }
        .homeCard()
        .accessibilityElement(children: .contain)
    }

    private func undoBar(_ result: SwitchResult, snapshot: HomeSnapshot) -> some View {
        let previous = result.previousRunning
        let oldName = previous.flatMap { snapshot.tree.node($0.activityID)?.name } ?? String(localized: "activity.unknown")
        let newName = snapshot.tree.node(result.started.activityID)?.name ?? String(localized: "activity.unknown")
        let duration = HomeTime.minutes(Int(max(0, result.started.startedAt.timeIntervalSince(previous?.startedAt ?? result.started.startedAt)) / 60))
        return VStack(alignment: .leading, spacing: 12) {
            Text(String(format: String(localized: "home.switched"), oldName, duration, newName))
            Button("action.undo") { Task { await model.undo() } }
                .accessibilityLabel(Text("a11y.undoSwitch"))
                .disabled(model.isBusy)
        }
        .homeCard()
        .accessibilityElement(children: .contain)
    }

    private func runningCard(_ running: TimeEntry, snapshot: HomeSnapshot, state: HomePresentation, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleRunningSummary(running: running, snapshot: snapshot) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("home.running", systemImage: "record.circle")
                        .font(.headline)
                    Text(snapshot.tree.node(running.activityID)?.name ?? String(localized: "activity.unknown"))
                        .font(.title2.bold())
                    // Equal columns at ordinary sizes; both clocks retain equal typography when stacked.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            clocks(running, snapshot: snapshot, state: state, now: now, intrinsic: true)
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            clocks(running, snapshot: snapshot, state: state, now: now, intrinsic: false)
                        }
                    }
                    if state.isCommitted, let activity = snapshot.tree.node(running.activityID),
                       !AccessibilityPresentation.outside(activity, tree: snapshot.tree), let parent = activity.parentID,
                       let summary = state.summaries[parent], let budget = summary.budgetMinutes {
                        Text(String(format: String(localized: "timer.parentRemaining"),
                            snapshot.tree.node(parent)?.name ?? String(localized: "activity.unknown"),
                            HomeTime.minutes(budget - summary.totalMinutes)))
                        deviation(summary)
                    }
                    if let minutes = running.plannedMinutes {
                        let elapsed = max(0, now.timeIntervalSince(running.startedAt))
                        let remaining = minutes - Int(elapsed / 60)
                        Text(String(format: String(localized: remaining >= 0 ? "timer.plan" : "timer.planExceeded"),
                            HomeTime.minutes(minutes), HomeTime.minutes(abs(remaining))))
                    } else {
                        Text("timer.noPlan")
                    }
                    if let activity = snapshot.tree.node(running.activityID) {
                        if AccessibilityPresentation.outside(activity, tree: snapshot.tree) { Text("a11y.outside") }
                        else if state.commitmentState == .pending { Text("a11y.pending") }
                    }
                }
            }
            if let notifications {
                if notifications.showsWarning(for: running) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("notifications.warning", systemImage: "bell.slash")
                        OpenNotificationSettingsButton()
                    }
                }
                if let issue = notifications.issueKey {
                    Label(LocalizedStringKey(issue), systemImage: "exclamationmark.triangle")
                }
            }
            AccessibleStack { timerActions }
        }
        .homeCard()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func clocks(_ running: TimeEntry, snapshot: HomeSnapshot, state: HomePresentation, now: Date, intrinsic: Bool) -> some View {
        clock("timer.elapsed", value: HomeTime.elapsed(since: running.startedAt, at: now), symbol: "arrow.up", intrinsic: intrinsic)
        if state.isCommitted, let activity = snapshot.tree.node(running.activityID),
           !AccessibilityPresentation.outside(activity, tree: snapshot.tree) {
            VStack(alignment: .leading, spacing: 8) {
                clock("timer.weekRemaining", value: state.summaries[running.activityID].flatMap { summary in
                    summary.budgetMinutes.map { HomeTime.minutes($0 - summary.totalMinutes) }
                } ?? String(localized: "timer.noBudget"), symbol: "arrow.down", intrinsic: intrinsic)
                if let summary = state.summaries[running.activityID] { deviation(summary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func clock(_ title: LocalizedStringKey, value: String, symbol: String, intrinsic: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
            Text(value).font(.title.monospacedDigit().bold())
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: intrinsic, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var runningName: String {
        model.snapshot.flatMap { snapshot in
            snapshot.running.flatMap { snapshot.tree.node($0.activityID)?.name }
        } ?? String(localized: "activity.unknown")
    }

    @ViewBuilder private var timerActions: some View {
        Button("action.stop", role: .destructive) { Task { await model.stop() } }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(AccessibilityPresentation.text("a11y.stop", runningName))
            .accessibilityIdentifier("timer.stop")
            .disabled(model.isBusy)
        Button("action.changePlan") {
            model.dismissUndo()
            showingPlan = true
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(AccessibilityPresentation.text("a11y.changePlan", runningName))
        .accessibilityIdentifier("timer.changePlan")
        .disabled(model.isBusy)
    }

    private func activitySection(_ title: LocalizedStringKey, ids: [ActivityID], empty: LocalizedStringKey,
                                 snapshot: HomeSnapshot, state: HomePresentation, hierarchical: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            if ids.isEmpty {
                Text(empty).foregroundStyle(.secondary)
                if hierarchical {
                    Button("home.createActivity", action: openActivityCreation)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("home.createActivity")
                }
            }
            ForEach(ids, id: \.self) { id in
                if let activity = snapshot.tree.node(id) {
                    if activity.isArchived {
                        activityRow(activity, snapshot: snapshot, state: state, hierarchical: hierarchical)
                    } else {
                        Button {
                            Task { await model.start(activity) }
                        } label: {
                            activityRow(activity, snapshot: snapshot, state: state, hierarchical: hierarchical)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AccessibilityPresentation.text(snapshot.running?.activityID == id ? "a11y.running" : "a11y.start", activity.name))
                        .accessibilityValue(AccessibilityPresentation.homeValue(activity, snapshot: snapshot, state: state))
                        .disabled(model.isBusy || snapshot.running?.activityID == id)
                        .accessibilityHint(Text(LocalizedStringKey(snapshot.running?.activityID == id ? "activity.runningHint" : "activity.startHint")))
                    }
                }
            }
        }
    }

    private func activityRow(_ activity: Activity, snapshot: HomeSnapshot, state: HomePresentation, hierarchical: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if hierarchical, let parent = activity.parentID {
                Text(String(format: String(localized: "activity.parent"),
                    snapshot.tree.node(parent)?.name ?? String(localized: "activity.unknown")))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(activity.name).font(.headline)
            if activity.isArchived { Label("activity.archived", systemImage: "archivebox") }
            if snapshot.running?.activityID == activity.id { Label("home.running", systemImage: "record.circle") }
            if let summary = state.summaries[activity.id] {
                Text(String(format: String(localized: "activity.actual"), HomeTime.minutes(summary.totalMinutes)))
                    .monospacedDigit()
                if state.isCommitted {
                    if let budget = summary.budgetMinutes {
                        Text(String(format: String(localized: summary.direction == .goal ? "activity.goalBudget" : "activity.capBudget"), HomeTime.minutes(budget)))
                    }
                }
                Text(AccessibilityPresentation.status(summary,
                    outside: AccessibilityPresentation.outside(activity, tree: snapshot.tree),
                    pending: state.commitmentState == .pending))
                    .foregroundStyle(state.isCommitted && (summary.deviationMinutes ?? 0) > 0
                        && !AccessibilityPresentation.outside(activity, tree: snapshot.tree) ? Color.red : Color.primary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func deviation(_ summary: ActivitySummary) -> some View {
        if let minutes = summary.deviationMinutes, minutes > 0 {
            // Both conditions use the same symbol, typography, and color intensity.
            Label {
                Text(String(format: String(localized: summary.direction == .goal ? "status.unmet" : "status.exceeded"), HomeTime.minutes(minutes)))
            } icon: { Image(systemName: "exclamationmark.circle") }
            .font(.subheadline.bold())
            .foregroundStyle(.red)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct PlannedMinutesSheet: View {
    let model: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var minuteInput = "60"
    private var minutes: Int? { Int(minuteInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
    @State private var hasPlan = true

    var body: some View {
        NavigationStack {
            Form {
                Toggle("plan.enabled", isOn: $hasPlan)
                if hasPlan {
                    // ASSUMPTION: Any positive whole minute is supported; do not silently impose a maximum.
                    AccessibleTextField("plan.minutes", text: $minuteInput)
                        .keyboardType(.numberPad)
                    Text("plan.guidance").font(.footnote)
                }
                Button("action.save") {
                    Task {
                        await model.changePlan(hasPlan ? minutes : nil)
                        if model.issue == nil { dismiss() }
                    }
                }
                .disabled(model.isBusy || (hasPlan && (minutes ?? 0) <= 0))
                .accessibilityLabel(Text("a11y.savePlan"))
            }
            .navigationTitle("action.changePlan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }.disabled(model.isBusy)
                }
            }
        }
        .alert("error.title", isPresented: Binding(
            get: { model.issue != nil }, set: { if !$0 { model.issue = nil } }
        )) {
            Button("action.ok", role: .cancel) { model.issue = nil }
        } message: {
            if let issue = model.issue { Text(LocalizedStringKey(issue.messageKey)) }
        }
        .interactiveDismissDisabled(model.isBusy)
        .onAppear {
            minuteInput = String(model.snapshot?.running?.plannedMinutes ?? 60)
            hasPlan = model.snapshot?.running?.plannedMinutes != nil
        }
    }
}

private extension View {
    func homeCard() -> some View {
        padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
