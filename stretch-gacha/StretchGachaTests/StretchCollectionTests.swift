import XCTest
@testable import StretchGacha

final class StretchCollectionTests: XCTestCase {

    private let catalog = StretchCatalog.shared

    // MARK: - 並び順・構造の不変条件（件数はデータ非依存でアサートする）

    func testTotalCellsMatchTotalCount() {
        let sections = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: [])
        XCTAssertEqual(sections.flatMap(\.cells).count, catalog.totalCount)
    }

    func testSectionCountMatchesNonEmptyBodyParts() {
        let sections = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: [])
        let nonEmptyParts = BodyPart.allCases.filter { !catalog.items(bodyPart: $0).isEmpty }
        XCTAssertEqual(sections.count, nonEmptyParts.count)
    }

    func testSectionsAreOrderedBySortOrderWithRestLast() {
        let sections = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: [])
        let orders = sections.map { BodyPart(rawValue: $0.id)!.sortOrder }
        XCTAssertEqual(orders, orders.sorted())
        XCTAssertEqual(sections.last?.id, BodyPart.rest.rawValue)
    }

    func testCellsWithinSectionAreOrderedByRarityThenCatalogIndex() {
        let sections = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: [])
        let catalogIndex = Dictionary(uniqueKeysWithValues:
            catalog.allItems.enumerated().map { ($0.element.id, $0.offset) })
        for section in sections {
            let keys = section.cells.map { cell -> (Int, Int) in
                (cell.rarity.sortOrder, catalogIndex[cell.id]!)
            }
            XCTAssertEqual(keys.map { $0 }, keys.sorted { $0 < $1 }, section.id)
        }
    }

    func testBuildIsDeterministic() {
        let a = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: ["neck-01"])
        let b = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: ["neck-01"])
        XCTAssertEqual(a, b)
    }

    // MARK: - 未入手 / 入手済みの表現

    func testEmptyOwnedSetMakesAllCellsUnowned() {
        let sections = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: [])
        for cell in sections.flatMap(\.cells) {
            XCTAssertFalse(cell.isOwned)
            XCTAssertEqual(cell.displayName, "???")
        }
    }

    func testFullOwnedSetMakesAllCellsOwned() {
        let all = Set(catalog.allItems.map(\.id))
        let sections = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: all)
        for cell in sections.flatMap(\.cells) {
            XCTAssertTrue(cell.isOwned)
            XCTAssertNotEqual(cell.displayName, "???")
        }
    }

    func testUnownedCellDoesNotCarryRealName() {
        let item = catalog.allItems[0]
        let cell = CollectionCellContent.make(from: item, isOwned: false)
        XCTAssertEqual(cell.displayName, "???")
        XCTAssertFalse(cell.accessibilityLabel.contains(item.name))
        XCTAssertEqual(cell.accessibilityLabel, "未入手、レア度 \(item.rarity.displayName)")
        // レア度は伏せない
        XCTAssertEqual(cell.rarityLabel, item.rarity.displayName)
    }

    func testOwnedCellShowsRealName() {
        let item = catalog.allItems[0]
        let cell = CollectionCellContent.make(from: item, isOwned: true)
        XCTAssertEqual(cell.displayName, item.name)
        XCTAssertEqual(cell.accessibilityLabel, "\(item.name)、レア度 \(item.rarity.displayName)、入手済み")
    }

    func testEmojiIsTruncatedAndEmptyEmojiIsSafe() {
        let base = catalog.allItems[0]
        let multi = StretchItem(id: base.id, name: base.name, kind: base.kind,
                                bodyPart: base.bodyPart, rarity: base.rarity,
                                durationSeconds: base.durationSeconds, emoji: "🙆🙆",
                                steps: base.steps, caution: base.caution)
        XCTAssertEqual(CollectionCellContent.make(from: multi, isOwned: true).emoji, "🙆")
        let empty = StretchItem(id: base.id, name: base.name, kind: base.kind,
                                bodyPart: base.bodyPart, rarity: base.rarity,
                                durationSeconds: base.durationSeconds, emoji: "",
                                steps: base.steps, caution: base.caution)
        XCTAssertEqual(CollectionCellContent.make(from: empty, isOwned: true).emoji, "")
    }

    func testUnknownIDsInOwnedSetAreIgnored() {
        let sections = CollectionSectionBuilder.build(items: catalog.allItems,
                                                      ownedItemIDs: ["ghost-99"])
        for cell in sections.flatMap(\.cells) {
            XCTAssertFalse(cell.isOwned)
        }
    }

    func testRewardCardsUseTheSameCellRepresentation() {
        let sections = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: [])
        let rest = sections.first { $0.id == BodyPart.rest.rawValue }
        XCTAssertNotNil(rest)
        for cell in rest!.cells {
            XCTAssertEqual(cell.rarityLabel, "UR")
            XCTAssertEqual(cell.displayName, "???")
        }
    }

    // MARK: - 純粋性・性能

    func testBuildPerformance10kWithin2Seconds() {
        let owned = Set(catalog.allItems.prefix(10).map(\.id))
        let start = Date()
        for _ in 0..<10_000 {
            _ = CollectionSectionBuilder.build(items: catalog.allItems, ownedItemIDs: owned)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    // 拡張性の実証: フィクスチャの追加種目が該当部位セクションの正しい位置に現れる
    func testFixtureExtraItemAppearsInCorrectSection() throws {
        let fixture = try StretchCatalog.load(bundle: Bundle(for: StretchCollectionTests.self),
                                              resource: "StretchCatalogFixture")
        let sections = CollectionSectionBuilder.build(items: fixture.allItems, ownedItemIDs: [])
        let neck = try XCTUnwrap(sections.first { $0.id == BodyPart.neck.rawValue })
        XCTAssertTrue(neck.cells.contains { $0.id == "neck-06" })
        let added = neck.cells.first { $0.id == "neck-06" }!
        XCTAssertFalse(added.isOwned)
        XCTAssertEqual(added.displayName, "???")
        // N レア度の末尾（カタログ記載順が最後のため）に並ぶ
        let nCells = neck.cells.filter { $0.rarity == .n }
        XCTAssertEqual(nCells.last?.id, "neck-06")
    }
}
