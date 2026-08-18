import SwiftUI

/// 履歴の 1 行（時刻・絵文字・種目名・レア度バッジ）。タップ・スワイプ操作を持たない。
struct HistoryRowView: View {
    let entry: PracticeEntry
    let item: StretchItem

    var body: some View {
        let time = TimeLabel.text(from: entry.completedAt)
        HStack(spacing: 12) {
            Text(verbatim: time)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(verbatim: String(item.emoji.prefix(1)))
                .accessibilityHidden(true)
            Text(verbatim: item.name)
                .font(.body)
                .lineLimit(1)
            Spacer()
            Text(verbatim: item.rarity.displayName)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(RarityStyle.accent(for: item.rarity), in: Capsule())
                .foregroundStyle(RarityStyle.badgeForeground(for: item.rarity))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText(time: time)))
    }

    private func accessibilityText(time: String) -> String {
        let parts = time.split(separator: ":")
        let spoken = parts.count == 2 ? "\(Int(parts[0]) ?? 0) 時 \(Int(parts[1]) ?? 0) 分" : time
        return "\(spoken)、\(item.name)、レア度 \(item.rarity.displayName)"
    }
}
