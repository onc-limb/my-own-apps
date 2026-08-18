import SwiftUI

/// 入手済み種目の詳細シート。stretch-card の .detail をそのまま使い、
/// 図鑑専用のカード表示を作らない。図鑑は閲覧のみ（タイマー起動導線を置かない）。
struct CollectionDetailSheet: View {
    let item: StretchItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StretchCardView(item: item, style: .detail) {
            Button {
                dismiss()
            } label: {
                Text(verbatim: "閉じる")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
