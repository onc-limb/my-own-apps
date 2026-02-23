import SwiftUI

struct CircularTimerView: View {
    let remainingSeconds: Int
    let totalSeconds: Int

    // MARK: - Computed Properties

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    private var isCompleted: Bool {
        remainingSeconds <= 0
    }

    private var ringColor: Color {
        isCompleted ? .green : .blue
    }

    private var timeText: String {
        let minutes = max(remainingSeconds, 0) / 60
        let seconds = max(remainingSeconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var minutes: Int {
        max(remainingSeconds, 0) / 60
    }

    private var seconds: Int {
        max(remainingSeconds, 0) % 60
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 14)

            // Foreground progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)

            // Center time text
            Text(timeText)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
        }
        .frame(width: 250, height: 250)
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("残り時間 \(minutes)分\(seconds)秒")
        .accessibilityValue("\(Int(progress * 100))パーセント")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        CircularTimerView(remainingSeconds: 150, totalSeconds: 300)
        CircularTimerView(remainingSeconds: 0, totalSeconds: 300)
    }
}
