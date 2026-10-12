import SwiftUI

/// 履歴画面。見るだけの画面（行タップ・削除・検索・フィルタを持たない）。
/// 表示は PracticeStore のメモリ索引から組み立て、fetch 0 本。
struct HistoryView: View {
    @Environment(PracticeStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if store.sections.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .onAppear { store.refreshForCurrentDay() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { store.refreshForCurrentDay() }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            streakHeader
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
            List {
                ForEach(store.sections) { section in
                    Section {
                        ForEach(Array(section.entries.enumerated()), id: \.offset) { _, entry in
                            if let item = StretchCatalog.shared.item(id: entry.itemID) {
                                HistoryRowView(entry: entry, item: item)
                            }
                        }
                    } header: {
                        Text(verbatim: "\(section.title) / \(section.entries.count) 回")
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var streakHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: "🔥")
                .accessibilityHidden(true)
            Text(verbatim: "\(store.streakDays)")
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            Text(verbatim: "日")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "連続日数"))
        .accessibilityValue(Text(verbatim: "\(store.streakDays) 日"))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(verbatim: "📖")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text(verbatim: "ガチャを回してストレッチをすると、ここに記録が残ります")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
