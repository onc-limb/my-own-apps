import UIKit

/// ハプティクスの実体。差し替え可能にするためクロージャとして注入する。
/// 効果音・BGM は持たない（フィードバックはハプティクスのみというユーザー決定）。
enum HapticPlayer {
    @MainActor
    static func impactMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
