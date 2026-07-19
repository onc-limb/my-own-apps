import SwiftData
import SwiftUI

struct ProjectManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkProject.sortOrder) private var projects: [WorkProject]
    @Query private var entries: [TimeEntry]

    @State private var editingProject: WorkProject?
    @State private var parentForNewProject: WorkProject?
    @State private var showingEditor = false
    @State private var deletingProject: WorkProject?

    private var roots: [WorkProject] { projects.filter { $0.parent == nil } }

    var body: some View {
        List {
            if roots.isEmpty {
                ContentUnavailableView(
                    "プロジェクトがありません",
                    systemImage: "folder.badge.plus",
                    description: Text("右上の＋から最初のプロジェクトを作成します。")
                )
            } else {
                ProjectTreeView(projects: roots) { project, depth in
                    HStack(spacing: 12) {
                        if depth > 0 { Color.clear.frame(width: CGFloat(depth) * 18) }
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading) {
                            Text(project.name)
                            if !project.children.isEmpty {
                                Text("子プロジェクト \(project.children.count)件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Menu {
                            Button("子プロジェクトを追加", systemImage: "folder.badge.plus") {
                                parentForNewProject = project
                                editingProject = nil
                                showingEditor = true
                            }
                            Button("編集", systemImage: "pencil") {
                                editingProject = project
                                parentForNewProject = nil
                                showingEditor = true
                            }
                            Button("削除", systemImage: "trash", role: .destructive) {
                                deletingProject = project
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("プロジェクト")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingProject = nil
                    parentForNewProject = nil
                    showingEditor = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ProjectEditorView(project: editingProject, initialParent: parentForNewProject)
        }
        .confirmationDialog(
            "「\(deletingProject?.name ?? "")」を削除しますか？",
            isPresented: Binding(
                get: { deletingProject != nil },
                set: { if !$0 { deletingProject = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("プロジェクトと記録を削除", role: .destructive) {
                guard let project = deletingProject else { return }
                if entries.first(where: { $0.endedAt == nil })?.project?.isDescendant(of: project) == true {
                    try? TimerService.stop(in: modelContext)
                }
                modelContext.delete(project)
                try? modelContext.save()
                deletingProject = nil
            }
        } message: {
            Text("子プロジェクトと、関連するすべての時間記録も削除されます。この操作は取り消せません。")
        }
    }
}

struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkProject.name) private var allProjects: [WorkProject]

    let project: WorkProject?
    let initialParent: WorkProject?

    @State private var name: String
    @State private var colorHex: String
    @State private var parentID: UUID?
    @State private var errorMessage: String?

    private let colors = ["#4F7CAC", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51", "#8E6CBB", "#D65DB1"]

    init(project: WorkProject?, initialParent: WorkProject?) {
        self.project = project
        self.initialParent = initialParent
        _name = State(initialValue: project?.name ?? "")
        _colorHex = State(initialValue: project?.colorHex ?? colors[0])
        _parentID = State(initialValue: project?.parent?.id ?? initialParent?.id)
    }

    private var parentCandidates: [WorkProject] {
        allProjects.filter { candidate in
            guard let project else { return true }
            return candidate.id != project.id && !candidate.isDescendant(of: project)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("プロジェクト") {
                    TextField("名前", text: $name)
                    Picker("親プロジェクト", selection: $parentID) {
                        Text("なし（ルート）").tag(UUID?.none)
                        ForEach(parentCandidates) { candidate in
                            Text(candidate.name).tag(Optional(candidate.id))
                        }
                    }
                }

                Section("カラー") {
                    HStack {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                colorHex = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if colorHex == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(project == nil ? "プロジェクトを追加" : "プロジェクトを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("保存できませんでした", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        let parent = allProjects.first { $0.id == parentID }
        if let project {
            project.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            project.colorHex = colorHex
            project.parent = parent
        } else {
            let newProject = WorkProject(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: colorHex,
                parent: parent,
                sortOrder: allProjects.count
            )
            modelContext.insert(newProject)
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

