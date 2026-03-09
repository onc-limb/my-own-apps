import SwiftUI
import SwiftData

struct ManageHabitsView: View {

    // MARK: - Properties

    @Query(sort: \Habit.sortOrder) private var allHabits: [Habit]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedHabit: Habit?
    @State private var showAddSheet = false

    private var activeHabits: [Habit] {
        allHabits.filter { $0.isActive }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if activeHabits.isEmpty {
                    ContentUnavailableView(
                        "習慣がありません",
                        systemImage: "list.bullet.rectangle",
                        description: Text("+ボタンから新しい習慣を追加できます")
                    )
                } else {
                    ForEach(activeHabits) { habit in
                        manageRow(habit)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedHabit = habit
                            }
                    }
                }
            }
            .navigationTitle("管理")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("習慣を追加")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                HabitFormView()
            }
            .sheet(item: $selectedHabit) { habit in
                HabitFormView(habit: habit)
            }
        }
    }

    // MARK: - Manage Row

    @ViewBuilder
    private func manageRow(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.name)
                .font(.body)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Label(frequencyDetailLabel(habit), systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if habit.timeLimitMinutes > 0 {
                    Label("\(habit.timeLimitMinutes)分", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func frequencyDetailLabel(_ habit: Habit) -> String {
        switch habit.frequencyType {
        case .daily:
            return "毎日"
        case .weeklyN:
            let base = "週\(habit.weeklyCount)回"
            if habit.effectiveWeekdays.isEmpty {
                return base
            }
            return "\(base) - \(weekdayLabel(habit.effectiveWeekdays))"
        }
    }

    private func weekdayLabel(_ weekdays: [Int]) -> String {
        let weekdayNames: [Int: String] = [
            1: "日", 2: "月", 3: "火", 4: "水", 5: "木", 6: "金", 7: "土"
        ]
        let sorted = weekdays.sorted()
        let names = sorted.compactMap { weekdayNames[$0] }
        return names.joined(separator: "・")
    }
}

// MARK: - Preview

#Preview {
    ManageHabitsView()
        .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}
