import SwiftUI

/// 図鑑の 1 セル。未入手は絵文字をシルエット化し、種目名を「???」（タップ中は「未入手」）で伏せる。
struct CollectionCellView: View {
    let content: CollectionCellContent
    let showsUnownedLabel: Bool   // 未入手セルのタップで「未入手」を表示中か

    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: content.rarityLabel)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(RarityStyle.accent(for: content.rarity), in: Capsule())
                .foregroundStyle(RarityStyle.badgeForeground(for: content.rarity))
            Text(verbatim: content.emoji)
                .font(.system(size: CollectionMetrics.emojiSize))
                .grayscale(content.isOwned ? 0 : CollectionMetrics.silhouetteGrayscale)
                .opacity(content.isOwned ? 1 : CollectionMetrics.silhouetteOpacity)
                .accessibilityHidden(true)
            Text(verbatim: showsUnownedLabel ? "未入手" : content.displayName)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundStyle(content.isOwned ? Color(.label) : Color(.secondaryLabel))
        }
        .padding(CollectionMetrics.cellPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CollectionMetrics.cellCornerRadius)
                .fill(content.isOwned
                      ? Color(.secondarySystemBackground)
                      : Color(.tertiarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CollectionMetrics.cellCornerRadius)
                .strokeBorder(content.isOwned
                              ? AnyShapeStyle(RarityStyle.accent(for: content.rarity).opacity(0.5))
                              : AnyShapeStyle(Color(.separator)),
                              lineWidth: CollectionMetrics.borderWidth)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: content.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(content.isOwned ? Text(verbatim: "詳細を開く") : Text(verbatim: ""))
    }
}
