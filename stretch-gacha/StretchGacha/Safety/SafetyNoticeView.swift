import SwiftUI

/// 初回注意書きの 1 画面。チュートリアルを兼ねない（見出し + 本文 3 項目 + ボタンのみ）。
/// UserDefaults を直接触らず、確認のクロージャだけを外から受ける。
struct SafetyNoticeView: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            // 不透明な全面背景。Color はヒットテスト対象になるため背面へタップが抜けない
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        Text(verbatim: SafetyNoticeText.emoji)
                            .font(.system(size: SafetyNoticeMetrics.emojiSize))
                            .accessibilityHidden(true)
                            .padding(.bottom, SafetyNoticeMetrics.emojiBottomSpacing)
                        Text(verbatim: SafetyNoticeText.headline)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, SafetyNoticeMetrics.headlineBottomSpacing)
                        VStack(spacing: SafetyNoticeMetrics.itemSpacing) {
                            ForEach(Array(SafetyNoticeText.body.enumerated()), id: \.offset) { _, line in
                                Text(verbatim: line)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, SafetyNoticeMetrics.screenPadding)
                }
                Button(action: onAccept) {
                    Text(verbatim: SafetyNoticeText.acceptButton)
                        .font(.headline)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(maxWidth: .infinity, minHeight: SafetyNoticeMetrics.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, SafetyNoticeMetrics.screenPadding)
            }
            .padding(.horizontal, SafetyNoticeMetrics.screenPadding)
        }
    }
}
