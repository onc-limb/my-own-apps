import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    let isCompleted: Bool
    var onComplete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.body)

                HStack(spacing: 12) {
                    Label("\(habit.timeLimitMinutes)分", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(frequencyLabel, systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .swipeActions(edge: .trailing) {
            if !isCompleted {
                Button {
                    onComplete()
                } label: {
                    Label("完了", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name)、\(habit.timeLimitMinutes)分、\(frequencyLabel)\(isCompleted ? "、完了済み" : "")")
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
            isCompleted: false
        ) {}

        HabitRowView(
            habit: Habit(
                name: "運動",
                timeLimitMinutes: 60,
                frequencyType: .weeklyN,
                weeklyCount: 3,
                sortOrder: 1
            ),
            isCompleted: true
        ) {}
        .foregroundStyle(.secondary)
    }
}
