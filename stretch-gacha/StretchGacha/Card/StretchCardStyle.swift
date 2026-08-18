import SwiftUI

/// スタイル 2 種の差分メトリクス。共通値は CardMetrics に置く。
enum StretchCardStyle {
    case result   // ガチャ結果
    case detail   // 図鑑の入手済み詳細・タイマー画面

    var emojiSize: CGFloat {
        switch self {
        case .result: 56
        case .detail: 40
        }
    }

    var nameFont: Font {
        switch self {
        case .result: .title2.bold()
        case .detail: .title3.bold()
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .result: 1.5
        case .detail: 1.0
        }
    }
}
