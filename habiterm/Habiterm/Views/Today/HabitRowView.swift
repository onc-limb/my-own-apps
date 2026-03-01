import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    let isCompleted: Bool
    var onStartTimer: () -> Void
    var onUncomplete: () -> Void
    var onMoveToBackyard: () -> Void
    var onComplete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.body)

                HStack(spacing: 12) {
                    if habit.timeLimitMinutes > 0 {
                        Label("\(habit.timeLimitMinutes)分", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label(frequencyLabel, systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !isCompleted {
                if habit.timeLimitMinutes > 0 {
                    Button {
                        onStartTimer()
                    } label: {
                        Image(systemName: "timer")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("タイマーを開始")
                } else {
                    Button {
                        onComplete()
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("完了にする")
                }
            }

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                onMoveToBackyard()
            } label: {
                Label("バックヤード", systemImage: "archivebox")
            }
            .tint(.purple)
        }
        .swipeActions(edge: .trailing) {
            if !isCompleted {
                Button {
                    onComplete()
                } label: {
                    Label("完了", systemImage: "checkmark")
                }
                .tint(.green)
            } else {
                Button {
                    onUncomplete()
                } label: {
                    Label("取消", systemImage: "arrow.uturn.backward")
                }
                .tint(.orange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name)\(habit.timeLimitMinutes > 0 ? "、\(habit.timeLimitMinutes)分" : "")、\(frequencyLabel)\(isCompleted ? "、完了済み、スワイプで取消" : "")、左スワイプでバックヤードに移動")
    }

    private var frequencyLabel: String {
        switch habit.frequencyType {
        case .daily:
            return "毎日"
        case .weeklyN:
            return "週\(habit.weeklyCount)回"
        }
    }
}

#Preview {
    List {
        HabitRowView(
            habit: Habit(
                name: "読書",
                timeLimitMinutes: 30,
                frequencyType: .daily,
                weeklyCount: 7,
                sortOrder: 0
            ),
            isCompleted: false,
            onStartTimer: {},
            onUncomplete: {},
            onMoveToBackyard: {}
        ) {}

        HabitRowView(
            habit: Habit(
                name: "運動",
                timeLimitMinutes: 60,
                frequencyType: .weeklyN,
                weeklyCount: 3,
                sortOrder: 1
            ),
            isCompleted: true,
            onStartTimer: {},
            onUncomplete: {},
            onMoveToBackyard: {}
        ) {}
        .foregroundStyle(.secondary)

        HabitRowView(
            habit: Habit(
                name: "瞑想",
                timeLimitMinutes: 0,
                frequencyType: .daily,
                weeklyCount: 7,
                sortOrder: 2
            ),
            isCompleted: false,
            onStartTimer: {},
            onUncomplete: {},
            onMoveToBackyard: {}
        ) {}
    }
}
