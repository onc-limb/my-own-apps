import SwiftUI
import SwiftData

struct BackyardView: View {

    // MARK: - Properties

    @Query(sort: \Habit.sortOrder) private var allHabits: [Habit]
    @Environment(\.modelContext) private var modelContext

    @State private var habitToActivate: Habit?

    private var backyardHabits: [Habit] {
        allHabits.filter { !$0.isActive }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if backyardHabits.isEmpty {
                    ContentUnavailableView(
                        "バックヤードは空です",
                        systemImage: "archivebox",
                        description: Text("Today画面で習慣をスワイプしてバックヤードに移動できます")
                    )
                } else {
                    ForEach(backyardHabits) { habit in
                        backyardRow(habit)
                    }
                }
            }
            .navigationTitle("バックヤード")
            .alert("アクティブにする", isPresented: .init(
                get: { habitToActivate != nil },
                set: { if !$0 { habitToActivate = nil } }
            )) {
                Button("アクティブにする") {
                    if let habit = habitToActivate {
                        habit.isActive = true
                    }
                    habitToActivate = nil
                }
                Button("キャンセル", role: .cancel) {
                    habitToActivate = nil
                }
            } message: {
                Text("この習慣をアクティブに戻しますか？Today・Weeklyに表示されるようになります。")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("バックヤード")
    }

    // MARK: - Backyard Row

    @ViewBuilder
    private func backyardRow(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.name)
                .font(.body)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                if habit.timeLimitMinutes > 0 {
                    Label("\(habit.timeLimitMinutes)分", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("タイマーなし", systemImage: "clock.badge.xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(frequencyLabel(habit), systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label("完了 \(habit.completionRecords.count)回", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let lastDate = habit.completionRecords.map(\.completedAt).max() {
                    Label("最終: \(lastDate, format: .dateTime.month().day())",
                          systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Label("記録なし", systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                habitToActivate = habit
            } label: {
                Label("アクティブにする", systemImage: "arrow.uturn.left")
            }
            .tint(.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name)、完了\(habit.completionRecords.count)回")
    }

    // MARK: - Helpers

    private func frequencyLabel(_ habit: Habit) -> String {
        switch habit.frequencyType {
        case .daily: return "毎日"
        case .weeklyN: return "週\(habit.weeklyCount)回"
        }
    }
}

// MARK: - Preview

#Preview {
    BackyardView()
        .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}
