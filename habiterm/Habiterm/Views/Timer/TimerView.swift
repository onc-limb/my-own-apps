import SwiftUI
import SwiftData

struct TimerView: View {

    // MARK: - Properties

    @State private var timerViewModel: TimerViewModel
    let todayViewModel: TodayViewModel

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(habit: Habit, todayViewModel: TodayViewModel) {
        _timerViewModel = State(initialValue: TimerViewModel(habit: habit))
        self.todayViewModel = todayViewModel
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Habit name
            Text(timerViewModel.habit.name)
                .font(.title)
                .fontWeight(.bold)

            // Circular timer
            CircularTimerView(
                remainingSeconds: timerViewModel.remainingSeconds,
                totalSeconds: timerViewModel.totalSeconds
            )

            // Control buttons
            controlButtons

            Spacer()

            // Complete button (always visible except idle)
            if timerViewModel.timerState != .idle {
                completeButton
            }
        }
        .padding()
        .navigationTitle(timerViewModel.habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            timerViewModel.cleanup()
        }
    }

    // MARK: - Control Buttons

    @ViewBuilder
    private var controlButtons: some View {
        switch timerViewModel.timerState {
        case .idle:
            Button {
                timerViewModel.start()
            } label: {
                Label("開始", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
            .accessibilityLabel("タイマーを開始")
            .accessibilityHint("タップするとカウントダウンが始まります")

        case .running:
            Button {
                timerViewModel.pause()
            } label: {
                Label("一時停止", systemImage: "pause.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .accessibilityLabel("一時停止")
            .accessibilityHint("タップするとタイマーを一時停止します")

        case .paused:
            HStack(spacing: 16) {
                Button {
                    timerViewModel.resume()
                } label: {
                    Label("再開", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .accessibilityLabel("タイマーを再開")
                .accessibilityHint("タップするとタイマーを再開します")

                Button {
                    timerViewModel.reset()
                } label: {
                    Label("リセット", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.gray)
                .accessibilityLabel("タイマーをリセット")
                .accessibilityHint("タップするとタイマーを初期状態に戻します")
            }

        case .finished:
            Button {
                completeAndDismiss()
            } label: {
                Label("完了として記録", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)
            .accessibilityLabel("完了として記録")
            .accessibilityHint("タップすると習慣を完了として記録します")
        }
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            completeAndDismiss()
        } label: {
            Label("完了として記録", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.green)
        .accessibilityLabel("途中で完了として記録")
        .accessibilityHint("タイマー途中でも習慣を完了として記録できます")
        .padding(.bottom)
    }

    // MARK: - Actions

    private func completeAndDismiss() {
        todayViewModel.completeHabit(timerViewModel.habit, durationSeconds: timerViewModel.elapsedSeconds)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TimerView(
            habit: Habit(
                name: "読書",
                timeLimitMinutes: 25,
                frequencyType: .daily,
                weeklyCount: 7,
                sortOrder: 0
            ),
            todayViewModel: {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try! ModelContainer(
                    for: Habit.self, CompletionRecord.self,
                    configurations: config
                )
                return TodayViewModel(modelContext: container.mainContext)
            }()
        )
    }
    .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}
