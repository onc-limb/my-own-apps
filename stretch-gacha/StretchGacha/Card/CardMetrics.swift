import Foundation

/// カード共通のレイアウト定数。カードの最大高さは持たない（親から与えられた高さに追従する）。
enum CardMetrics {
    static let padding: CGFloat = 20
    static let cornerRadius: CGFloat = 16
    static let headerSpacing: CGFloat = 12
    static let emojiBottomSpacing: CGFloat = 8
    static let nameBottomSpacing: CGFloat = 6
    static let durationBottomSpacing: CGFloat = 14
    static let separatorBottomSpacing: CGFloat = 14
    static let stepSpacing: CGFloat = 10
    static let stepNumberWidth: CGFloat = 24
    static let stepNumberGap: CGFloat = 8
    static let cautionCornerRadius: CGFloat = 8
}
