import SwiftUI

/// L1 の 3 画面（ガチャ / 図鑑 / 履歴）を束ねるタブ。
/// タブ選択状態は永続化しない（起動のたびにガチャから始まる方が学習容易性に沿う）。
struct RootTabView: View {
    var body: some View {
        TabView {
            GachaView()
                .tabItem { Label("ガチャ", systemImage: "sparkles") }
            CollectionView()
                .tabItem { Label("図鑑", systemImage: "square.grid.2x2") }
            HistoryView()
                .tabItem { Label("履歴", systemImage: "list.bullet") }
        }
    }
}
