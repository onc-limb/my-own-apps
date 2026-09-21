import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("保存するデータ") {
                Text("プロジェクト、ページ、時間記録、表示言語をこの端末内に保存します。")
            }

            Section("外部送信") {
                Text("TimeBranchは、解析、広告、アカウント機能を使用せず、データを開発者や第三者へ送信しません。")
            }

            Section("共有") {
                Text("JSONファイルは、共有ボタンを操作した場合に限り、選択した共有先へ渡されます。")
            }

            Section("削除") {
                Text("設定画面の「すべてのデータを削除」、またはアプリの削除によって端末内のデータを削除できます。")
            }
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
