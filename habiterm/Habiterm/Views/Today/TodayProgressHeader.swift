import SwiftUI

struct TodayProgressHeader: View {
    let completedCount: Int
    let totalCount: Int

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var percentText: String {
        "\(Int(progress * 100))%"
    }

    private var progressColor: Color {
        progress >= 1.0 ? .green : .blue
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // MARK: - 円形プログレスバー
            ZStack {
                Circle()
                    .stroke(lineWidth: 12)
                    .opacity(0.2)
                    .foregroundColor(progressColor)

                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .foregroundColor(progressColor)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                Text(percentText)
                    .font(.title)
                    .bold()
            }
            .frame(width: 120, height: 120)

            // MARK: - 完了数/全体数テキスト
            Text("\(completedCount) / \(totalCount)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(totalCount)件中\(completedCount)件完了、達成率\(Int(progress * 100))パーセント")
    }
}

#Preview {
    VStack(spacing: 20) {
        TodayProgressHeader(completedCount: 2, totalCount: 3)
        TodayProgressHeader(completedCount: 3, totalCount: 3)
        TodayProgressHeader(completedCount: 0, totalCount: 0)
    }
}
