import SwiftUI
import SwiftData

struct WeeklyCalendarView: View {

    // MARK: - Properties

    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    WeekHeaderRow()

                    if habits.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(habits) { habit in
                            WeeklyHabitRow(habit: habit)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Weekly")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("週間カレンダー")
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "習慣がありません",
            systemImage: "calendar",
            description: Text("習慣を追加してください")
        )
        .padding(.top, 40)
    }
}

// MARK: - Preview

#Preview {
    WeeklyCalendarView()
        .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}
