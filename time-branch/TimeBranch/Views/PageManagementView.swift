import SwiftData
import SwiftUI

struct PageManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DisplayPage.sortOrder) private var pages: [DisplayPage]

    @State private var editingPage: DisplayPage?
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                if pages.isEmpty {
                    ContentUnavailableView("ページがありません", systemImage: "rectangle.stack.badge.plus")
                }
                ForEach(pages) { page in
                    Button {
                        editingPage = page
                        showingEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(page.name).foregroundStyle(.primary)
                                Text("登録プロジェクト \(page.projects.count)件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(pages[index]) }
                    try? modelContext.save()
                }
            }
            .navigationTitle("表示ページ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingPage = nil
                        showingEditor = true
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                PageEditorView(page: editingPage)
            }
        }
    }
}

struct PageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkProject.sortOrder) private var projects: [WorkProject]
    @Query private var pages: [DisplayPage]

    let page: DisplayPage?
    @State private var name: String
    @State private var selectedIDs: Set<UUID>
    @State private var errorMessage: LocalizedStringKey?

    init(page: DisplayPage?) {
        self.page = page
        _name = State(initialValue: page?.name ?? "")
        _selectedIDs = State(initialValue: Set(page?.projects.map(\.id) ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ページ名") {
                    TextField("例: 仕事", text: $name)
                }
                Section("表示するプロジェクト") {
                    ProjectTreeView(projects: projects.filter { $0.parent == nil }) { project, depth in
                        Button {
                            if selectedIDs.contains(project.id) {
                                selectedIDs.remove(project.id)
                            } else {
                                selectedIDs.insert(project.id)
                            }
                        } label: {
                            HStack {
                                if depth > 0 { Color.clear.frame(width: CGFloat(depth) * 18) }
                                Circle().fill(Color(hex: project.colorHex)).frame(width: 9, height: 9)
                                Text(project.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selectedIDs.contains(project.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(project.id) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(page == nil ? LocalizedStringKey("ページを追加") : LocalizedStringKey("ページを編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
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
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        let selected = projects.filter { selectedIDs.contains($0.id) }
        if let page {
            page.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            page.projects = selected
        } else {
            modelContext.insert(DisplayPage(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: pages.count,
                projects: selected
            ))
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = LocalizedStringKey(error.localizedDescription)
        }
    }
}
