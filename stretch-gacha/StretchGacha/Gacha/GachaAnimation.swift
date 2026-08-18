import Foundation

/// 演出秒数・区間の定数。ビュー側にマジックナンバーを書かない。
enum GachaAnimation {
    static let normalDuration: Double = 1.2       // N / R
    static let highlightedDuration: Double = 1.8  // SR / UR
    static let reducedMotionDuration: Double = 0.3

    /// SR/UR でハプティクスを発火する時点
    static let hapticMoment: Double = 0.9
    static let reducedMotionHapticMoment: Double = 0.15

    // N/R: 揺れ 0.35 → 回転拡大 0.85 → フラッシュ 1.05 → クロスフェード 1.20
    static let normalShakeEnd: Double = 0.35
    static let normalSpinEnd: Double = 0.85
    static let normalFlashEnd: Double = 1.05

    // SR/UR: 揺れ 0.45 → 色味変化 0.90 → 回転拡大 1.50 → フラッシュ 1.70 → クロスフェード 1.80
    static let highlightedShakeEnd: Double = 0.45
    static let highlightedTintEnd: Double = 0.9
    static let highlightedSpinEnd: Double = 1.5
    static let highlightedFlashEnd: Double = 1.7
}
