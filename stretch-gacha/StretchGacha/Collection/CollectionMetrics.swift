import Foundation

/// 図鑑のレイアウト定数（設計基準: iPhone SE 375×667。16+107+11+107+11+107+16 = 375）。
enum CollectionMetrics {
    static let columnCount = 3
    static let screenPadding: CGFloat = 16
    static let columnSpacing: CGFloat = 11
    static let rowSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 16
    static let cellPadding: CGFloat = 8
    static let emojiSize: CGFloat = 40
    static let borderWidth: CGFloat = 1.0
    static let cellCornerRadius: CGFloat = 12
    /// シルエット（未入手の絵文字）の階調と不透明度
    static let silhouetteGrayscale: Double = 1.0
    static let silhouetteOpacity: Double = 0.35
}
