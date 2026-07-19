import SwiftData
import SwiftUI

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DisplayPage.sortOrder) private var pages: [DisplayPage]
    @Query(sort: \WorkProject.sortOrder) private var projects: [WorkProject]
    @Query(sort: \TimeEntry.startedAt, order: .reverse) private var entries: [TimeEntry]

    @State private var selectedPageID: UUID?
    @State private var showingPageEditor = false
    @State private var errorMessage: LocalizedStringKey?

    private var activeEntry: TimeEntry? { entries.first { $0.endedAt == nil } }
    private var selectedPage: DisplayPage? { pages.first { $0.id == selectedPageID } }

    private var visibleRoots: [WorkProject] {
        guard let selectedPage else { return projects.filter { $0.parent == nil } }
        let selectedIDs = Set(selectedPage.projects.map(\.id))
        return selectedPage.projects.filter { project in
            guard let parent = project.parent else { return true }
            return !selectedIDs.contains(parent.id)
        }
    }

    var body: some View {
        List {
            if pages.isEmpty {
                ContentUnavailableView(
                    "表示ページがありません",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("ページを作成して、表示するプロジェクトを登録してください。")
                )
            } else if visibleRoots.isEmpty {
                ContentUnavailableView(
                    "プロジェクトがありません",
                    systemImage: "folder.badge.plus",
                    description: Text("ページの編集からプロジェクトを追加できます。")
                )
            } else {
                Section {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        ProjectTreeView(projects: visibleRoots) { project, depth in
                            timerRow(project: project, depth: depth, now: context.date)
                        }
                    }
                } header: {
                    if let activeProject = activeEntry?.project {
                        Text("計測中: \(activeProject.name)")
                    } else {
                        Text("プロジェクトをタップして開始")
                    }
                }
            }
        }
        .navigationTitle("TimeBranch")
        .safeAreaInset(edge: .top) {
            if !pages.isEmpty {
                pagePicker
                    .background(.bar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPageEditor = true } label: {
                    Label("ページを管理", systemImage: "rectangle.stack.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingPageEditor) {
            PageManagementView()
        }
        .alert("操作できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear { selectInitialPage() }
        .onChange(of: pages.map(\.id)) { _, _ in selectInitialPage() }
    }

    private var pagePicker: some View {
        Picker("表示ページ", selection: $selectedPageID) {
            ForEach(pages) { page in
                Text(page.name).tag(Optional(page.id))
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func timerRow(project: WorkProject, depth: Int, now: Date) -> some View {
        let directActive = activeEntry?.project?.id == project.id
        let ancestorActive = activeEntry?.project?.isDescendant(of: project) == true

        Button {
            do {
                try TimerService.toggle(project: project, in: modelContext)
            } catch {
                errorMessage = LocalizedStringKey(error.localizedDescription)
            }
        } label: {
            HStack(spacing: 12) {
                if depth > 0 {
                    Color.clear.frame(width: CGFloat(depth) * 18)
                }
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .foregroundStyle(.primary)
                    if ancestorActive, !directActive {
                        Text("子プロジェクトを計測中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if ancestorActive, activeEntry != nil {
                    Text(AppFormatters.duration(activeDuration(for: project, now: now)))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(directActive ? Color.accentColor : Color.secondary)
                    Image(systemName: directActive ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(directActive ? .red : Color(hex: project.colorHex))
                } else {
                    Image(systemName: "play.circle")
                        .foregroundStyle(Color(hex: project.colorHex))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectInitialPage() {
        if selectedPageID == nil || !pages.contains(where: { $0.id == selectedPageID }) {
            selectedPageID = pages.first?.id
        }
    }

    private func activeDuration(for project: WorkProject, now: Date) -> TimeInterval {
        guard let activeEntry,
              let activeProject = activeEntry.project,
              activeProject.isDescendant(of: project) else { return 0 }

        var contiguousStart = activeEntry.startedAt
        var usedEntryIDs = Set<UUID>()
        let completed = entries
            .filter { entry in
                guard let recordedProject = entry.project, entry.endedAt != nil else { return false }
                return recordedProject.isDescendant(of: project)
            }
            .sorted { $0.startedAt > $1.startedAt }

        var foundPrevious = true
        while foundPrevious {
            foundPrevious = false
            if let previous = completed.first(where: { entry in
                guard let end = entry.endedAt else { return false }
                return !usedEntryIDs.contains(entry.id)
                    && abs(end.timeIntervalSince(contiguousStart)) < 0.001
            }) {
                usedEntryIDs.insert(previous.id)
                contiguousStart = previous.startedAt
                foundPrevious = true
            }
        }
        return max(0, now.timeIntervalSince(contiguousStart))
    }
}
