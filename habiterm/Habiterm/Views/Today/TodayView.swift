import SwiftUI
import SwiftData

struct TodayView: View {

    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddSheet = false
    @State private var selectedHabit: Habit?

    var body: some View {
        NavigationStack {
            let viewModel = TodayViewModel(modelContext: modelContext)
            let todayHabits = habits.filter { viewModel.shouldShowToday($0) }
            let completed = todayHabits.filter { viewModel.isCompletedToday($0) }
            let incomplete = todayHabits.filter { !viewModel.isCompletedToday($0) }

            List {
                Section {
                    TodayProgressHeader(
                        completedCount: completed.count,
                        totalCount: todayHabits.count
                    )
                }
                .listRowInsets(EdgeInsets())

                if !incomplete.isEmpty {
                    Section("未完了") {
                        ForEach(incomplete) { habit in
                            HabitRowView(habit: habit, isCompleted: false) {
                                viewModel.completeHabit(habit)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedHabit = habit
                            }
                        }
                    }
                }

                if !completed.isEmpty {
                    Section("完了済み") {
                        ForEach(completed) { habit in
                            HabitRowView(habit: habit, isCompleted: true) {}
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedHabit = habit
                                }
                        }
                    }
                }
            }
            .navigationTitle("Today")
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
}

#Preview {
    TodayView()
        .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}
