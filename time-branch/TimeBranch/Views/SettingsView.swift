import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pages: [DisplayPage]
    @Query private var projects: [WorkProject]
    @Query private var entries: [TimeEntry]
    @Binding var languageCode: String
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: LocalizedStringKey?

    var body: some View {
        Form {
            Section("言語") {
                Picker("表示言語", selection: $languageCode) {
                    Text("日本語").tag(AppLanguage.japanese.rawValue)
                    Text("英語").tag(AppLanguage.english.rawValue)
                }
            }

            Section("データ") {
                LabeledContent("保存場所", value: "このiPhone内")
                Text("時間記録は端末内だけに保存されます。アプリを削除するとデータも削除されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("JSON書き出しは共有・確認用です。現在のバージョンではJSONから復元できません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("すべてのデータを削除", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .disabled(pages.isEmpty && projects.isEmpty && entries.isEmpty)
            }
        }
        .navigationTitle("設定")
        .confirmationDialog(
            "すべてのデータを削除しますか？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("完全に削除", role: .destructive) { deleteAllData() }
        } message: {
            Text("すべてのページ、プロジェクト、時間記録が削除されます。この操作は取り消せません。")
        }
        .alert("削除できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteAllData() {
        for entry in entries { modelContext.delete(entry) }
        for page in pages { modelContext.delete(page) }
        for project in projects { modelContext.delete(project) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = LocalizedStringKey(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(languageCode: .constant(AppLanguage.japanese.rawValue))
    }
    .environment(\.locale, AppLanguage.japanese.locale)
}
