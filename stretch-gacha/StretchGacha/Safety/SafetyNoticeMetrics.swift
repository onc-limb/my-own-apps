import Foundation

/// レイアウト定数（設計基準: iPhone SE 375×667・セーフエリア 647pt。
/// 24+58+16+29+20+168+252+56+24 = 647）。
enum SafetyNoticeMetrics {
    static let screenPadding: CGFloat = 24
    static let emojiSize: CGFloat = 48
    static let emojiBottomSpacing: CGFloat = 16
    static let headlineBottomSpacing: CGFloat = 20
    static let itemSpacing: CGFloat = 12
    static let buttonHeight: CGFloat = 56
}
