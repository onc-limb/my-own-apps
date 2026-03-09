import SwiftUI
import SwiftData

struct WeeklyCalendarView: View {

    // MARK: - Properties

    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @AppStorage("dayStartHour") private var dayStartHour: Int = 4
    @State private var selectedWeekStart: Date = {
        let hour = UserDefaults.standard.object(forKey: "dayStartHour") as? Int ?? 4
        return CalendarHelper.weekStartDate(for: Date(), dayStartHour: hour)
    }()

    private var currentWeekDays: [Date] {
        CalendarHelper.weekDays(for: selectedWeekStart, dayStartHour: dayStartHour)
    }

    private var isCurrentWeek: Bool {
        let currentStart = CalendarHelper.weekStartDate(for: Date(), dayStartHour: dayStartHour)
        return Calendar.current.isDate(selectedWeekStart, inSameDayAs: currentStart)
    }

    private var isBeyondMaxFutureWeek: Bool {
        let currentStart = CalendarHelper.weekStartDate(for: Date(), dayStartHour: dayStartHour)
        guard let maxFuture = Calendar.current.date(byAdding: .weekOfYear, value: 5, to: currentStart) else {
            return true
        }
        return selectedWeekStart >= maxFuture
    }

    private var activeHabits: [Habit] {
        habits.filter { $0.isActive }
    }

    private var weekRangeText: String {
        let days = currentWeekDays
        guard let first = days.first, let last = days.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return "\(formatter.string(from: first)) 〜 \(formatter.string(from: last))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    weekNavigationBar

                    WeekHeaderRow(dates: currentWeekDays)

                    if activeHabits.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(activeHabits) { habit in
                            WeeklyHabitRow(habit: habit, dates: currentWeekDays)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Weekly")
        }
        .onAppear {
            selectedWeekStart = CalendarHelper.weekStartDate(for: Date(), dayStartHour: dayStartHour)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("週間カレンダー")
    }

    // MARK: - Week Navigation

    private var weekNavigationBar: some View {
        HStack {
            Button {
                if let prev = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStart) {
                    selectedWeekStart = prev
                }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(weekRangeText)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Button {
                if let next = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStart) {
                    selectedWeekStart = next
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isBeyondMaxFutureWeek)

            if !isCurrentWeek {
                Button("今週") {
                    selectedWeekStart = CalendarHelper.weekStartDate(for: Date(), dayStartHour: dayStartHour)
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
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
