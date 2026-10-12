import SwiftUI

/// 図鑑画面。何も永続化せず、入手済み集合のスナップショットから毎回組み立てる。
/// 描画経路に I/O・非同期・アニメーションを置かない。
struct CollectionView: View {
    @Environment(PracticeStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var sections: [CollectionSection] = []
    @State private var selectedItem: StretchItem?
    @State private var revealedUnownedID: String?

    private let columns = Array(repeating: GridItem(.flexible(),
                                                    spacing: CollectionMetrics.columnSpacing),
                                count: CollectionMetrics.columnCount)

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: columns,
                          alignment: .center,
                          spacing: CollectionMetrics.rowSpacing) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.cells) { cell in
                                CollectionCellView(content: cell,
                                                   showsUnownedLabel: revealedUnownedID == cell.id)
                                    .onTapGesture { handleTap(cell) }
                            }
                        } header: {
                            Text(verbatim: section.title)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, CollectionMetrics.sectionSpacing)
                        }
                    }
                }
                .padding(.horizontal, CollectionMetrics.screenPadding)
                .padding(.vertical, CollectionMetrics.screenPadding)
            }
        }
        .onAppear {
            revealedUnownedID = nil
            rebuild()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { rebuild() }
        }
        .sheet(item: $selectedItem) { item in
            CollectionDetailSheet(item: item)
        }
    }

    private func handleTap(_ cell: CollectionCellContent) {
        if cell.isOwned {
            // 入手済みだけがシートを開く（未入手の情報が構造的に漏れない）
            selectedItem = StretchCatalog.shared.item(id: cell.id)
        } else {
            // 未入手は「???」⇄「未入手」のトグルのみ。同時に出るのは常に 1 つ
            revealedUnownedID = revealedUnownedID == cell.id ? nil : cell.id
        }
    }

    private func rebuild() {
        sections = CollectionSectionBuilder.build(items: StretchCatalog.shared.allItems,
                                                  ownedItemIDs: store.ownedItemIDs())
    }
}
