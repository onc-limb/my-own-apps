import SwiftUI
import SwiftData

struct TodayView: View {

    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dayStartHour") private var dayStartHour: Int = 4

    @State private var viewModel: TodayViewModel?
    @State private var timerHabit: Habit?
    @State private var habitToMoveToBackyard: Habit?

    var body: some View {
        NavigationStack {
            if let viewModel {
                let todayHabits = habits.filter { $0.isActive && viewModel.shouldShowToday($0) }
                let completed = todayHabits.filter { viewModel.isCompletedToday($0) }
                let incomplete = todayHabits.filter { !viewModel.isCompletedToday($0) }

                List {
                    Section {
                        HStack {
                            Button {
                                viewModel.selectedDate = Calendar.current.date(
                                    byAdding: .day, value: -1, to: viewModel.selectedDate
                                ) ?? viewModel.selectedDate
                            } label: {
                                Image(systemName: "chevron.left")
                            }

                            Spacer()

                            Text(dateDisplayText(viewModel.selectedDate))
                                .font(.headline)

                            Spacer()

                            Button {
                                viewModel.selectedDate = Calendar.current.date(
                                    byAdding: .day, value: 1, to: viewModel.selectedDate
                                ) ?? viewModel.selectedDate
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(viewModel.isToday)

                            if !viewModel.isToday {
                                Button("今日") {
                                    viewModel.selectedDate = CalendarHelper.logicalDate(
                                        for: Date(), dayStartHour: dayStartHour
                                    )
                                }
                                .font(.caption)
                            }
                        }
                    }

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
                                HabitRowView(habit: habit, isCompleted: false, onStartTimer: {
                                    timerHabit = habit
                                }, onUncomplete: {}, onMoveToBackyard: {
                                    habitToMoveToBackyard = habit
                                }) {
                                    viewModel.completeHabit(habit)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if habit.timeLimitMinutes > 0 {
                                        timerHabit = habit
                                    } else {
                                        viewModel.completeHabit(habit)
                                    }
                                }
                            }
                        }
                    }

                    if !completed.isEmpty {
                        Section("完了済み") {
                            ForEach(completed) { habit in
                                HabitRowView(habit: habit, isCompleted: true, onStartTimer: {}, onUncomplete: {
                                    viewModel.uncompleteHabit(habit)
                                }, onMoveToBackyard: {
                                    habitToMoveToBackyard = habit
                                }) {}
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationDestination(item: $timerHabit) { habit in
                    TimerView(habit: habit, todayViewModel: viewModel)
                }
                .navigationTitle("Today")
                .alert("バックヤードに移動", isPresented: .init(
                    get: { habitToMoveToBackyard != nil },
                    set: { if !$0 { habitToMoveToBackyard = nil } }
                )) {
                    Button("移動する") {
                        if let habit = habitToMoveToBackyard {
                            viewModel.moveToBackyard(habit)
                        }
                        habitToMoveToBackyard = nil
                    }
                    Button("キャンセル", role: .cancel) {
                        habitToMoveToBackyard = nil
                    }
                } message: {
                    Text("バックヤードに移動しますか？過去の記録は保持されます。")
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TodayViewModel(modelContext: modelContext, dayStartHour: dayStartHour)
            }
        }
    }

    private func dateDisplayText(_ date: Date) -> String {
        if viewModel?.isToday == true {
            return "今日"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 (E)"
        return formatter.string(from: date)
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}
