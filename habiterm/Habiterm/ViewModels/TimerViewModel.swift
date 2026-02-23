import Foundation
import UIKit
import Combine

@MainActor @Observable
final class TimerViewModel {

    // MARK: - Timer State

    enum TimerState {
        case idle, running, paused, finished
    }

    // MARK: - Properties

    private(set) var totalSeconds: Int
    private(set) var remainingSeconds: Int
    private(set) var timerState: TimerState = .idle
    let habit: Habit

    private var timer: Timer?
    private var backgroundDate: Date?
    private let notificationService = NotificationService.shared
    private var backgroundObservers: [Any] = []

    // MARK: - Computed Properties

    /// Elapsed seconds since the timer started.
    var elapsedSeconds: Int { totalSeconds - remainingSeconds }

    // MARK: - Init

    init(habit: Habit) {
        self.habit = habit
        self.totalSeconds = habit.timeLimitMinutes * 60
        self.remainingSeconds = habit.timeLimitMinutes * 60
        setupBackgroundObservers()
    }

    // MARK: - Cleanup

    func cleanup() {
        timer?.invalidate()
        timer = nil
        notificationService.cancelTimerNotification()
        for observer in backgroundObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        backgroundObservers = []
    }

    // MARK: - Actions

    func start() {
        timerState = .running
        startTimer()
        notificationService.scheduleTimerNotification(
            habitName: habit.name,
            seconds: TimeInterval(remainingSeconds)
        )
    }

    func pause() {
        timerState = .paused
        timer?.invalidate()
        timer = nil
        notificationService.cancelTimerNotification()
    }

    func resume() {
        timerState = .running
        startTimer()
        notificationService.scheduleTimerNotification(
            habitName: habit.name,
            seconds: TimeInterval(remainingSeconds)
        )
    }

    func reset() {
        timerState = .idle
        timer?.invalidate()
        timer = nil
        remainingSeconds = totalSeconds
        notificationService.cancelTimerNotification()
    }

    // MARK: - Private Helpers

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            remainingSeconds = 0
            timerState = .finished
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - Background Handling

    private func setupBackgroundObservers() {
        let resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.backgroundDate = Date()
            }
        }

        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleBecomeActive()
            }
        }

        backgroundObservers = [resignObserver, activeObserver]
    }

    private func handleBecomeActive() {
        guard let bgDate = backgroundDate, timerState == .running else { return }
        let elapsed = Int(Date().timeIntervalSince(bgDate))
        remainingSeconds = max(0, remainingSeconds - elapsed)
        if remainingSeconds <= 0 {
            timerState = .finished
            timer?.invalidate()
            timer = nil
        }
        backgroundDate = nil
    }
}
