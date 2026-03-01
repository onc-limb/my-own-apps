import SwiftUI

struct WeeklyHabitRow: View {

    // MARK: - Properties

    let habit: Habit
    let dates: [Date]
    @AppStorage("dayStartHour") private var dayStartHour: Int = 4
    @State private var isExpanded: Bool = false

    // MARK: - Body

    var body: some View {
        HStack {
            Text(habit.name)
                .frame(width: 100, alignment: .leading)
                .lineLimit(isExpanded ? nil : 1)
                .truncationMode(.tail)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            ForEach(dates, id: \.self) { date in
                cellView(for: date)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(accessibilityLabel(for: date))
            }
        }
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(for date: Date) -> some View {
        let weekday = Calendar.current.component(.weekday, from: date)
        let isAssignedDay = habit.assignedWeekdays.isEmpty || habit.assignedWeekdays.contains(weekday)

        if !isAssignedDay {
            Image(systemName: "minus")
                .foregroundStyle(.gray.opacity(0.3))
        } else if !CalendarHelper.isApplicable(habit: habit, on: date, dayStartHour: dayStartHour) {
            Image(systemName: "minus")
                .foregroundStyle(.gray.opacity(0.3))
        } else if CalendarHelper.isCompleted(habit: habit, on: date, dayStartHour: dayStartHour) {
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

        let weekday = Calendar.current.component(.weekday, from: date)
        let isAssignedDay = habit.assignedWeekdays.isEmpty || habit.assignedWeekdays.contains(weekday)

        if !isAssignedDay {
            return "\(habit.name) \(dateString) 対象外"
        } else if !CalendarHelper.isApplicable(habit: habit, on: date, dayStartHour: dayStartHour) {
            return "\(habit.name) \(dateString) 対象外"
        } else if CalendarHelper.isCompleted(habit: habit, on: date, dayStartHour: dayStartHour) {
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
            ),
            dates: CalendarHelper.weekDays(for: Date())
        )

        WeeklyHabitRow(
            habit: Habit(
                name: "運動トレーニング",
                timeLimitMinutes: 60,
                frequencyType: .weeklyN,
                weeklyCount: 3,
                sortOrder: 1
            ),
            dates: CalendarHelper.weekDays(for: Date())
        )
    }
    .padding()
}
