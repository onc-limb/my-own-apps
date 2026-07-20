import SwiftData
import SwiftUI

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkProject.sortOrder) private var projects: [WorkProject]
    @Query(sort: \TimeEntry.startedAt, order: .reverse) private var entries: [TimeEntry]

    @State private var period: ReportPeriod = .day
    @State private var referenceDate = Date.now
    @State private var editingEntry: TimeEntry?
    @State private var errorMessage: LocalizedStringKey?

    private var interval: DateInterval { period.interval(containing: referenceDate) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let totals = ReportService.totals(projects: projects, entries: entries, interval: interval, now: timeline.date)
            let filtered = ReportService.filteredEntries(entries, interval: interval, now: timeline.date)

            List {
                Section {
                    Picker("期間", selection: $period) {
                        ForEach(ReportPeriod.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("基準日", selection: $referenceDate, displayedComponents: .date)
                }

                Section("プロジェクト別") {
                    if totals.isEmpty {
                        ContentUnavailableView("記録がありません", systemImage: "chart.bar")
                    } else {
                        ForEach(totals) { total in
                            HStack {
                                Circle().fill(Color(hex: total.project.colorHex)).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(total.project.name)
                                    if let parent = total.project.parent {
                                        Text("親: \(parent.name)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(AppFormatters.duration(total.seconds))
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }

                Section("時間記録") {
                    ForEach(filtered) { entry in
                        Button { editingEntry = entry } label: {
                            entryRow(entry: entry, now: timeline.date)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("削除", role: .destructive) {
                                modelContext.delete(entry)
                                try? modelContext.save()
                            }
                            Button("編集") { editingEntry = entry }
                                .tint(.blue)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let exportFile = try? ExportService.makeFile(
                        totals: totals,
                        entries: filtered,
                        interval: interval,
                        now: timeline.date
                    ) {
                        ShareLink(item: exportFile, preview: SharePreview(exportFile.filename)) {
                            Label("JSONを書き出す", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button { errorMessage = "JSONファイルを作成できませんでした。" } label: {
                            Label("JSONを書き出す", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { editingEntry = TimeEntryPlaceholder.make(projects: projects) } label: {
                        Label("記録を追加", systemImage: "plus")
                    }
                    .disabled(projects.isEmpty)
                }
            }
        }
        .navigationTitle("レポート")
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(entry: entry, isNew: entry.modelContext == nil)
        }
        .alert("処理できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func entryRow(entry: TimeEntry, now: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let project = entry.project {
                    Text(project.name)
                } else {
                    Text("削除済みプロジェクト")
                }
                Text(entry.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(AppFormatters.duration(entry.duration(until: now)))
                .font(.system(.subheadline, design: .monospaced))
            Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

}

private enum TimeEntryPlaceholder {
    static func make(projects: [WorkProject]) -> TimeEntry? {
        guard let project = projects.first else { return nil }
        return TimeEntry(project: project, startedAt: .now.addingTimeInterval(-3600), endedAt: .now)
    }
}

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkProject.name) private var projects: [WorkProject]
    @Query(sort: \TimeEntry.startedAt) private var entries: [TimeEntry]

    let entry: TimeEntry
    let isNew: Bool

    @State private var projectID: UUID?
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var note: String
    @State private var errorMessage: LocalizedStringKey?

    init(entry: TimeEntry, isNew: Bool) {
        self.entry = entry
        self.isNew = isNew
        _projectID = State(initialValue: entry.project?.id)
        _startedAt = State(initialValue: entry.startedAt)
        _endedAt = State(initialValue: entry.endedAt ?? .now)
        _note = State(initialValue: entry.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isNew && entry.endedAt == nil {
                    Section {
                        Label("この記録は計測中です。保存すると指定した終了時刻で停止します。", systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("プロジェクト", selection: $projectID) {
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                DatePicker("開始", selection: $startedAt)
                DatePicker("終了", selection: $endedAt, in: startedAt...)
                TextField("メモ（任意）", text: $note, axis: .vertical)
            }
            .navigationTitle(isNew ? LocalizedStringKey("記録を追加") : LocalizedStringKey("記録を編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(projectID == nil || endedAt < startedAt)
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
        guard let project = projects.first(where: { $0.id == projectID }) else { return }
        do {
            try TimeEntryValidationService.validate(
                startedAt: startedAt,
                endedAt: endedAt,
                excluding: isNew ? nil : entry.id,
                entries: entries
            )
            entry.project = project
            entry.startedAt = startedAt
            entry.endedAt = endedAt
            entry.note = note
            if isNew { modelContext.insert(entry) }
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = LocalizedStringKey(error.localizedDescription)
        }
    }
}
