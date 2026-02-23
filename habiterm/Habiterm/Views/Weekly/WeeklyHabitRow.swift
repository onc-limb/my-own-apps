import SwiftUI

struct WeeklyHabitRow: View {

    // MARK: - Properties

    let habit: Habit

    // MARK: - Body

    var body: some View {
        HStack {
            Text(habit.name)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            ForEach(CalendarHelper.pastSevenDays(), id: \.self) { date in
                cellView(for: date)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(accessibilityLabel(for: date))
            }
        }
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(for date: Date) -> some View {
        if !CalendarHelper.isApplicable(habit: habit, on: date) {
            Image(systemName: "minus")
                .foregroundStyle(.gray.opacity(0.3))
        } else if CalendarHelper.isCompleted(habit: habit, on: date) {
            Image(systemName: "circle.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        let dateString = formatter.string(from: date)

        if !CalendarHelper.isApplicable(habit: habit, on: date) {
            return "\(habit.name) \(dateString) 対象外"
        } else if CalendarHelper.isCompleted(habit: habit, on: date) {
            return "\(habit.name) \(dateString) 完了"
        } else {
            return "\(habit.name) \(dateString) 未完了"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        WeeklyHabitRow(
            habit: Habit(
                name: "読書",
                timeLimitMinutes: 30,
                frequencyType: .daily,
                weeklyCount: 7,
                sortOrder: 0
            )
        )

        WeeklyHabitRow(
            habit: Habit(
                name: "運動トレーニング",
                timeLimitMinutes: 60,
                frequencyType: .weeklyN,
                weeklyCount: 3,
                sortOrder: 1
            )
        )
    }
    .padding()
}
