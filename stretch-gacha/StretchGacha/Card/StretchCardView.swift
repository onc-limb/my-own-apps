import SwiftUI

/// ガチャ結果と図鑑詳細の両方で使うカード部品。状態を持たず、StretchItem の純粋な関数として描画する。
/// 独自アニメーション・非同期・I/O を持たない（gacha-draw の時間予算に 0 秒を追加する）。
struct StretchCardView<Footer: View>: View {
    let item: StretchItem
    var style: StretchCardStyle = .result
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        let content = StretchCardContent.make(from: item)
        VStack(spacing: 0) {
            card(content)
            Spacer(minLength: 16)
            footer()
        }
        .padding(.horizontal, CardMetrics.padding)
        .padding(.vertical, 16)
    }

    private func card(_ content: StretchCardContent) -> some View {
        VStack(spacing: 0) {
            header(content)
                .padding(.bottom, CardMetrics.headerSpacing)
            Text(verbatim: content.emoji)
                .font(.system(size: style.emojiSize))
                .frame(minHeight: style.emojiSize + 12)
                .accessibilityHidden(true)
                .padding(.bottom, CardMetrics.emojiBottomSpacing)
            Text(verbatim: content.name)
                .font(style.nameFont)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.bottom, CardMetrics.nameBottomSpacing)
            if let duration = content.durationText {
                Text(verbatim: "⏱ \(duration)")
                    .font(.subheadline)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, CardMetrics.durationBottomSpacing)
            }
            if !content.steps.isEmpty {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                    .padding(.bottom, CardMetrics.separatorBottomSpacing)
                stepsArea(content)
            }
        }
        .padding(CardMetrics.padding)
        .background(cardBackground(content.rarity))
        .overlay(
            RoundedRectangle(cornerRadius: CardMetrics.cornerRadius)
                .strokeBorder(RarityStyle.accent(for: content.rarity).opacity(0.5),
                              lineWidth: style.borderWidth)
        )
        .accessibilityElement(children: .contain)
    }

    private func header(_ content: StretchCardContent) -> some View {
        HStack {
            Text(verbatim: content.rarityLabel)
                .font(.caption.bold())
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(RarityStyle.accent(for: content.rarity), in: Capsule())
                .foregroundStyle(RarityStyle.badgeForeground(for: content.rarity))
            Spacer()
            Text(verbatim: content.bodyPartLabel)
                .font(.caption.bold())
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(Color(.separator)))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityHeader(content)))
    }

    private func accessibilityHeader(_ content: StretchCardContent) -> String {
        var parts = ["レア度 \(content.rarityLabel)", content.bodyPartLabel, content.name]
        if let duration = content.durationText { parts.append(duration) }
        return parts.joined(separator: "、")
    }

    private func stepsArea(_ content: StretchCardContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CardMetrics.stepSpacing) {
                ForEach(Array(content.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: CardMetrics.stepNumberGap) {
                        Text(verbatim: "\(index + 1)")
                            .font(.body.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: CardMetrics.stepNumberWidth, alignment: .trailing)
                        Text(verbatim: step)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "手順 \(index + 1)、\(step)"))
                }
                if let caution = content.caution {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: "⚠️")
                        Text(verbatim: caution)
                    }
                    .font(.caption)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: CardMetrics.cautionCornerRadius))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "注意、\(caution)"))
                }
            }
        }
    }

    private func cardBackground(_ rarity: Rarity) -> some View {
        RoundedRectangle(cornerRadius: CardMetrics.cornerRadius)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: CardMetrics.cornerRadius)
                    .fill(rarity == .sr || rarity == .ur
                          ? RarityStyle.accent(for: rarity).opacity(0.08)
                          : Color.clear)
            )
    }
}

extension StretchCardView where Footer == EmptyView {
    init(item: StretchItem, style: StretchCardStyle = .result) {
        self.init(item: item, style: style) { EmptyView() }
    }
}
