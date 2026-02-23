import SwiftUI

struct TodayProgressHeader: View {
    let completedCount: Int
    let totalCount: Int

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(completedCount) / \(totalCount)")
                .font(.headline)
                .accessibilityLabel("\(totalCount)件中\(completedCount)件完了")

            ProgressView(value: progress)
                .tint(progress >= 1.0 ? .green : .blue)
        }
        .padding()
    }
}

#Preview {
    TodayProgressHeader(completedCount: 3, totalCount: 5)
}
