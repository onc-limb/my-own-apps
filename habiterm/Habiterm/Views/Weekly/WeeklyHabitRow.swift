import SwiftUI

struct WeeklyHabitRow: View {

    // MARK: - Properties

    let habit: Habit
    let dates: [Date]
    @AppStorage("dayStartHour") private var dayStartHour: Int = 4
    @State private var isExpanded: Bool = false

    private var isWeeklyN: Bool { habit.frequencyType == .weeklyN }

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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isWeeklyN {
                            let weekday = Calendar.current.component(.weekday, from: date)
                            toggleWeekday(weekday)
                        }
                    }
                    .overlay {
                        if isWeeklyN {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        }
                    }
                    .accessibilityLabel(accessibilityLabel(for: date))
            }
        }
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(for date: Date) -> some View {
        let weekday = Calendar.current.component(.weekday, from: date)
        let isCompleted = CalendarHelper.isCompleted(habit: habit, on: date, dayStartHour: dayStartHour)
        let isApplicable = CalendarHelper.isApplicable(habit: habit, on: date, dayStartHour: dayStartHour)
        let isAssignedDay = habit.effectiveWeekdays.isEmpty || habit.effectiveWeekdays.contains(weekday)

        if isCompleted {
            // 1. Completed → green filled circle
            Image(systemName: "circle.fill")
                .foregroundStyle(.green)
        } else if !isApplicable {
            Image(systemName: "minus")
                .foregroundStyle(.gray.opacity(0.3))
        } else if !isAssignedDay {
            // 4. Not assigned and not completed → minus gray
            Image(systemName: "minus")
                .foregroundStyle(.gray.opacity(0.3))
        } else if shouldGreyOut(date: date) {
            // 3. Assigned but greyed out due to unscheduled completions
            Image(systemName: "circle")
                .foregroundStyle(.gray.opacity(0.3))
        } else {
            // 5. Assigned and incomplete → circle gray
            Image(systemName: "circle")
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Grey Out Logic

    /// Determines if an assigned-but-incomplete day should be greyed out.
    /// This happens when the weekly count is already met and an earlier
    /// unassigned day was completed instead (unscheduled completion).
    private func shouldGreyOut(date: Date) -> Bool {
        guard habit.frequencyType == .weeklyN else { return false }
        let completionCount = CalendarHelper.completionCountInWeek(
            habit: habit, weekOf: date, dayStartHour: dayStartHour
        )
        guard completionCount >= habit.weeklyCount else { return false }

        let weekDays = CalendarHelper.weekDays(for: date, dayStartHour: dayStartHour)
        for day in weekDays {
            guard day < date else { break }
            let dayWeekday = Calendar.current.component(.weekday, from: day)
            let isUnscheduled = !habit.effectiveWeekdays.contains(dayWeekday)
            if isUnscheduled && CalendarHelper.isCompleted(habit: habit, on: day, dayStartHour: dayStartHour) {
                return true
            }
        }
        return false
    }

    // MARK: - Weekday Toggle

    private func toggleWeekday(_ weekday: Int) {
        // Initialize from defaults if currently empty
        if habit.assignedWeekdays.isEmpty {
            habit.assignedWeekdays = habit.effectiveWeekdays
        }

        if habit.assignedWeekdays.contains(weekday) {
            // Trying to turn OFF — must keep at least weeklyCount days
            guard habit.assignedWeekdays.count > habit.weeklyCount else { return }
            habit.assignedWeekdays.removeAll { $0 == weekday }
        } else {
            // Trying to turn ON
            if habit.assignedWeekdays.count < habit.weeklyCount {
                habit.assignedWeekdays.append(weekday)
            } else {
                // Replace: remove the furthest-back weekday in the week (Mon→Sun)
                // Week order: Mon(2)=0, Tue(3)=1, ..., Sat(7)=5, Sun(1)=6
                let weekOrder: [Int: Int] = [2: 0, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5, 1: 6]
                if let toRemove = habit.assignedWeekdays
                    .filter({ $0 != weekday })
                    .max(by: { (weekOrder[$0] ?? 0) < (weekOrder[$1] ?? 0) }) {
                    habit.assignedWeekdays.removeAll { $0 == toRemove }
                    habit.assignedWeekdays.append(weekday)
                }
            }
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        let dateString = formatter.string(from: date)

        let weekday = Calendar.current.component(.weekday, from: date)
        let isAssignedDay = habit.effectiveWeekdays.isEmpty || habit.effectiveWeekdays.contains(weekday)

        if CalendarHelper.isCompleted(habit: habit, on: date, dayStartHour: dayStartHour) {
            return "\(habit.name) \(dateString) 完了"
        } else if !CalendarHelper.isApplicable(habit: habit, on: date, dayStartHour: dayStartHour) {
            return "\(habit.name) \(dateString) 対象外"
        } else if !isAssignedDay {
            return "\(habit.name) \(dateString) 対象外"
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
