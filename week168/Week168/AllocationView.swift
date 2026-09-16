import SwiftUI
import Week168Domain

struct AllocationView: View {
    @Bindable var model: AllocationViewModel
    @State private var editing: Activity?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weekPicker
                if let report = model.report {
                    totals(report)
                    if model.state == .unused {
                        Text("allocation.unused")
                    } else if model.isCommitted {
                        Label("allocation.confirmed", systemImage: "checkmark.circle")
                    } else {
                        Text("allocation.guidance")
                        if model.hasDraft { Text("allocation.draftNotice").font(.footnote) }
                    }
                    AllocationProblems(model: model)
                    ForEach(model.nodes, id: \.activityID) { node in
                        Button {
                            editing = model.tree?.node(node.activityID)
                        } label: {
                            AllocationRow(model: model, node: node)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isBusy)
                    }
                    if model.nodes.isEmpty { Text("allocation.empty") }
                    if model.state != .unused {
                        Button("allocation.commit") { Task { await model.commit() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(!model.canCommit || model.isCommitted)
                    }
                } else if model.isBusy {
                    ProgressView("home.loading")
                }
                AllocationError(model: model)
            }
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("tab.allocation")
        .background(Color(uiColor: .systemGroupedBackground))
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .sheet(item: $editing) { activity in
            AllocationEditor(model: model, activity: activity)
        }
    }

    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let week = model.week, let settings = model.settings {
                let interval = TimeAxis.interval(of: week, settings: settings)
                Text(weekLabel(interval.start, settings: settings))
                    .font(.title2.bold())
            }
            ViewThatFits(in: .horizontal) {
                HStack { weekButtons.fixedSize() }
                VStack(alignment: .leading) { weekButtons }
            }
        }
        .disabled(model.isBusy)
    }

    private func weekLabel(_ date: Date, settings: CalendarSettings) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: settings.timeZoneIdentifier)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    @ViewBuilder private var weekButtons: some View {
        Button("allocation.previousWeek") { Task { await model.selectWeek(offset: -1) } }
        Button("allocation.thisWeek") { Task { await model.selectWeek(offset: nil) } }
        Button("allocation.nextWeek") { Task { await model.selectWeek(offset: 1) } }
    }

    private func totals(_ report: AllocationReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(allocationText("allocation.totalWish", report.totalWishMinutes))
            Text(allocationText("allocation.totalCommitted", report.totalCommittedMinutes))
            if let capacity = report.capacityMinutes {
                Text(allocationText("allocation.capacity", capacity))
                if report.capacityOverflowMinutes > 0 {
                    AllocationDeviation(key: "allocation.overflow", minutes: report.capacityOverflowMinutes)
                } else {
                    Text(allocationText("allocation.remaining", capacity - report.totalCommittedMinutes))
                }
                if report.wishOverflowMinutes > 0 {
                    Text(allocationText("allocation.wishOverflow", report.wishOverflowMinutes))
                }
            }
        }
        .font(.headline)
        .allocationCard()
    }
}

private struct AllocationRow: View {
    let model: AllocationViewModel
    let node: AllocationNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let parent = model.tree?.node(node.activityID)?.parentID {
                Text(String(format: String(localized: "activity.parent"), model.name(parent)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(model.name(node.activityID)).font(.headline)
            Text(LocalizedStringKey(node.direction.map { $0 == .cap ? "allocation.cap" : "allocation.goal" } ?? "allocation.unset"))
            if let value = node.committedMinutes {
                Text(allocationText("allocation.committed", value))
            } else {
                Text("allocation.notEntered")
            }
            if let wish = node.wishMinutes, wish != node.committedMinutes {
                Text(allocationText("allocation.wish", wish))
            }
            if model.invalidIDs.contains(node.activityID) { Text("allocation.invalidMinutes").foregroundStyle(.orange) }
            if node.overflowMinutes > 0 {
                AllocationDeviation(key: "allocation.overflow", minutes: node.overflowMinutes)
            }
            // ASSUMPTION: Before commitment, unmet refers to wish minus draft allocation, never actual-time judgment.
            if node.direction == .goal, let wish = node.wishMinutes, wish > (node.committedMinutes ?? 0) {
                AllocationDeviation(key: "allocation.wishUnmet", minutes: wish - (node.committedMinutes ?? 0))
            }
            if !model.children(node.activityID).isEmpty {
                AllocationBar(committed: node.committedMinutes ?? 0, children: node.childrenCommittedMinutes)
                Text(allocationText("allocation.childrenTotal", node.childrenCommittedMinutes)).font(.subheadline)
            }
            if model.hasSharedChildren(node.activityID), let remaining = node.unallocatedMinutes {
                Text(allocationText("allocation.unallocated", remaining))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allocationCard()
        .accessibilityElement(children: .combine)
    }
}

private struct AllocationBar: View {
    let committed: Int
    let children: Int

    var body: some View {
        GeometryReader { geometry in
            let scale = Double(max(1, max(committed, children)))
            HStack(spacing: 0) {
                Rectangle().fill(Color.accentColor)
                    .frame(width: geometry.size.width * Double(min(committed, children)) / scale)
                Rectangle().fill(Color.orange)
                    .frame(width: geometry.size.width * Double(max(0, children - committed)) / scale)
                Spacer(minLength: 0)
            }
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

private struct AllocationDeviation: View {
    let key: String
    let minutes: Int
    var body: some View {
        Label {
            Text(allocationText(key, minutes))
        } icon: { Image(systemName: "exclamationmark.circle") }
        .font(.subheadline.bold())
        .foregroundStyle(.orange)
    }
}

private struct AllocationProblems: View {
    let model: AllocationViewModel
    var body: some View {
        if let report = model.report, !report.canCommit || !model.invalidIDs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("allocation.cannotCommit").font(.headline)
                ForEach(model.invalidIDs, id: \.self) { id in
                    Text(model.name(id))
                    Text("allocation.invalidMinutes")
                }
                if report.capacityOverflowMinutes > 0 {
                    Text(allocationText("allocation.reduceTotal", report.capacityOverflowMinutes))
                    // ASSUMPTION: A shared total has no unique per-activity excess. Name every contributing
                    // root with its allocation and state the exact reduction required for the group.
                    ForEach(model.nodes.filter {
                        model.tree?.node($0.activityID)?.parentID == nil && ($0.committedMinutes ?? 0) > 0
                    }, id: \.activityID) { node in
                        Text(String(format: String(localized: "allocation.contributor"),
                            model.name(node.activityID), HomeTime.minutes(node.committedMinutes ?? 0)))
                    }
                }
                ForEach(model.nodes.filter { $0.overflowMinutes > 0 }, id: \.activityID) { node in
                    Text(String(format: String(localized: "allocation.namedOverflow"),
                        model.name(node.activityID), HomeTime.minutes(node.overflowMinutes)))
                    ForEach(model.children(node.activityID), id: \.self) { id in
                        Text(String(format: String(localized: "allocation.contributor"),
                            model.name(id), HomeTime.minutes(model.node(id)?.committedMinutes ?? 0)))
                    }
                }
                Text("allocation.adjustHint")
            }
            .allocationCard()
        }
    }
}

private struct AllocationEditor: View {
    let model: AllocationViewModel
    let activity: Activity
    @Environment(\.dismiss) private var dismiss

    private var reduction: Int { model.node(activity.id)?.overflowMinutes ?? 0 }
    private var children: [ActivityID] { model.descendants(activity.id) }
    private var contributors: [ActivityID] {
        let reported = model.affectedChildren[activity.id] ?? []
        return reported.isEmpty ? model.children(activity.id) : reported
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AllocationBudgetFields(model: model, id: activity.id)
                }
                if !children.isEmpty {
                    Section("allocation.reallocate") {
                        Text(allocationText("allocation.childrenTotal", model.node(activity.id)?.childrenCommittedMinutes ?? 0))
                        Text(allocationText("allocation.newFrame", model.node(activity.id)?.committedMinutes ?? 0))
                        Text(allocationText("allocation.reduction", reduction)).font(.headline)
                        if reduction > 0 {
                            ForEach(contributors, id: \.self) { id in
                                Text(String(format: String(localized: "allocation.contributor"),
                                    model.name(id), HomeTime.minutes(model.node(id)?.committedMinutes ?? 0)))
                            }
                        }
                        Text("allocation.reallocationHint")
                    }
                    ForEach(children, id: \.self) { id in
                        Section {
                            AllocationBudgetFields(model: model, id: id)
                            if let node = model.node(id), node.overflowMinutes > 0 {
                                AllocationDeviation(key: "allocation.overflow", minutes: node.overflowMinutes)
                            }
                        }
                    }
                }
                Section { AllocationProblems(model: model) }
                Section { AllocationError(model: model) }
                Section {
                    Text("allocation.draftNotice")
                    Button("allocation.keepDraft") { dismiss() }
                        .disabled(model.isBusy || model.isPreviewing || reduction > 0 || !model.invalidIDs.isEmpty)
                }
            }
            .navigationTitle(activity.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Closing keeps the session draft; it never commits an invalid allocation.
                    Button("allocation.closeDraft") { dismiss() }.disabled(model.isBusy)
                }
            }
        }
        .interactiveDismissDisabled(model.isBusy)
        .task { await model.validateDraft(parent: activity.id) }
    }
}

private struct AllocationBudgetFields: View {
    let model: AllocationViewModel
    let id: ActivityID
    @State private var wish = ""
    @State private var direction: BudgetDirection = .cap
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.name(id)).font(.headline)
            if let parent = model.tree?.node(id)?.parentID {
                Text(String(format: String(localized: "activity.parent"), model.name(parent))).font(.caption)
            }
            TextField("allocation.wishMinutes", text: $wish).keyboardType(.numberPad)
                .accessibilityLabel(Text("allocation.wishMinutes"))
            Picker("allocation.direction", selection: $direction) {
                Text("allocation.cap").tag(BudgetDirection.cap)
                Text("allocation.goal").tag(BudgetDirection.goal)
            }
            .pickerStyle(.menu)
            if model.node(id)?.mode == .unset { Text("allocation.enableBudgetHint").font(.footnote) }
            Button("allocation.saveWish") {
                Task {
                    if let minutes = Int(wish.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        saved = await model.saveWish(minutes, direction: direction, for: id)
                    }
                }
            }
            // S-1: No capacity/parent/draft validation gates wish saving.
            .disabled(model.isBusy || Int(wish.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
            if saved { Text("allocation.wishSaved").font(.footnote) }
            if model.node(id)?.direction != nil, model.node(id)?.mode == .managed {
                TextField("allocation.committedMinutes", text: Binding(
                    get: { model.input(id) }, set: { model.setDraft($0, for: id) }
                ))
                .keyboardType(.numberPad)
                .accessibilityLabel(Text("allocation.committedMinutes"))
                Text("allocation.blankIsZero").font(.footnote)
                if let value = model.node(id)?.wishMinutes {
                    Text(allocationText("allocation.wish", value))
                }
            } else {
                Text("allocation.wishFirst")
            }
        }
        .disabled(model.isBusy)
        .onAppear {
            wish = model.node(id)?.wishMinutes.map(String.init) ?? ""
            direction = model.node(id)?.direction ?? .cap
        }
        .onChange(of: wish) { _, _ in saved = false }
        .onChange(of: direction) { _, _ in saved = false }
    }
}

private struct AllocationError: View {
    let model: AllocationViewModel
    var body: some View {
        if let key = model.issueKey {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(key))
                Button("action.retry") { Task { await model.refresh() } }.disabled(model.isBusy)
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private func allocationText(_ key: String, _ minutes: Int) -> String {
    String(format: String(localized: String.LocalizationValue(key)), HomeTime.minutes(minutes))
}

private extension View {
    func allocationCard() -> some View {
        padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
