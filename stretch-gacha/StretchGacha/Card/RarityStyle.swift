import SwiftUI

/// レア度 → 色の単一の正。カード・ガチャ演出・履歴バッジ・図鑑はすべてここを参照し、
/// レア度色を他の場所で再定義しない。switch は default を書かない
/// （レア度追加時にコンパイルエラーで気づけるようにする）。
enum RarityStyle {

    /// バッジ塗り・枠線・演出の色（0xRRGGBB）。テストのコントラスト検証からも参照する
    static func accentRGB(for rarity: Rarity) -> (light: UInt32, dark: UInt32) {
        switch rarity {
        case .n: (0x6E6E73, 0x98989D)
        case .r: (0x2A62C4, 0x6FA8FF)
        case .sr: (0x7B4FD1, 0xB69BFF)
        case .ur: (0x8C6000, 0xF0C14B)
        }
    }

    static let badgeForegroundRGB: (light: UInt32, dark: UInt32) = (0xFFFFFF, 0x1C1C1E)

    static func accent(for rarity: Rarity) -> Color {
        let rgb = accentRGB(for: rarity)
        return AdaptiveColor.make(light: rgb.light, dark: rgb.dark)
    }

    static func badgeForeground(for rarity: Rarity) -> Color {
        AdaptiveColor.make(light: badgeForegroundRGB.light, dark: badgeForegroundRGB.dark)
    }
}
