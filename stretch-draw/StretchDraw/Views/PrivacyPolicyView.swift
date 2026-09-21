import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("保存するデータ") {
                    Text("その日の抽選結果、引き直し回数、完了状況をこの端末内に保存します。")
                }

                Section("外部送信") {
                    Text("Stretch Drawは、アカウント、解析、広告を使用せず、データを開発者や第三者へ送信しません。")
                }

                Section("削除") {
                    Text("アプリを削除すると、端末内の記録も削除されます。")
                }
            }
            .navigationTitle("プライバシーポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
