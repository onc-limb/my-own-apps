import SwiftUI
import UIKit

/// アセットカタログを追加せず、ライト / ダークの 2 色から Color を作る。
enum AdaptiveColor {

    /// 引数は 0xRRGGBB
    static func make(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        })
    }

    private static func uiColor(_ rgb: UInt32) -> UIColor {
        let (r, g, b) = components(rgb)
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    /// sRGB 成分（0.0...1.0）。テストのコントラスト比計算からも使う
    static func components(_ rgb: UInt32) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        (CGFloat((rgb >> 16) & 0xFF) / 255,
         CGFloat((rgb >> 8) & 0xFF) / 255,
         CGFloat(rgb & 0xFF) / 255)
    }
}
