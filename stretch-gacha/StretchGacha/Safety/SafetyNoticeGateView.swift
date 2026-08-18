import SwiftUI

/// 背面を知らない汎用オーバーレイ。中身はジェネリックな Content で受け、
/// RootTabView の型を参照しない（タブ構成が変わっても本機能は不変）。
/// fullScreenCover / sheet を使わないのは、最初のフレームから注意書きを出すため
/// （モーダル提示だと背面が一瞬見えてからせり上がる）。
struct SafetyNoticeGateView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var isPresented: Bool
    private let store: SafetyNoticeStore

    init(store: SafetyNoticeStore = SafetyNoticeStore(),
         @ViewBuilder content: @escaping () -> Content) {
        self.store = store
        self.content = content
        // 判定は init で 1 回だけ。scenePhase では再評価しない（1 セッション中に値は変わらない）
        _isPresented = State(initialValue:
            SafetyNoticeGate.shouldPresent(acceptedVersion: store.acceptedVersion))
    }

    var body: some View {
        ZStack {
            content()
                .accessibilityHidden(isPresented)
            if isPresented {
                SafetyNoticeView {
                    store.accept()
                    isPresented = false   // アニメーションなしで即時解除
                }
            }
        }
    }
}
