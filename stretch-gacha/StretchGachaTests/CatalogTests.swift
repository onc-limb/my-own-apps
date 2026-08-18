import XCTest
@testable import StretchGacha

final class CatalogTests: XCTestCase {

    private var catalog: StretchCatalog!

    override func setUpWithError() throws {
        catalog = try StretchCatalog.load(bundle: Bundle(for: StretchGacha.DailyDrawState.self))
    }

    func testLoadSucceedsAndValidatorReturnsNoViolations() {
        XCTAssertEqual(CatalogValidator.validate(catalog), [])
    }

    // 件数は範囲でアサートする（種目を 1 件足すたびにテストが落ちないように）
    func testItemCountIsWithinRange() {
        XCTAssertTrue((20...30).contains(catalog.totalCount))
    }

    func testRewardAndStretchCounts() {
        let rewards = catalog.rewardItems.count
        XCTAssertTrue((1...4).contains(rewards))
        XCTAssertEqual(catalog.stretchItems.count, catalog.totalCount - rewards)
    }

    func testRarityCountsAreMonotonicNonIncreasing() {
        let counts = [Rarity.n, .r, .sr, .ur].map { catalog.items(rarity: $0).count }
        XCTAssertEqual(counts, counts.sorted(by: >))
        XCTAssertTrue(counts.allSatisfy { $0 >= 1 })
    }

    func testRarityWeightsSumToExactly100() {
        for rarity in Rarity.allCases {
            XCTAssertGreaterThanOrEqual(catalog.weight(for: rarity), 1)
        }
        let sum = Rarity.allCases.map { catalog.weight(for: $0) }.reduce(0, +)
        XCTAssertEqual(sum, 100)
    }

    func testIDsMatchPatternAndAreUnique() {
        var seen = Set<String>()
        for item in catalog.allItems {
            XCTAssertNotNil(item.id.wholeMatch(of: /^[a-z]{3,12}-[0-9]{2}$/), item.id)
            XCTAssertTrue(seen.insert(item.id).inserted, "id 重複: \(item.id)")
        }
    }

    func testDurationsAreWithinRange() {
        for item in catalog.allItems {
            XCTAssertTrue((20...90).contains(item.durationSeconds), item.id)
        }
    }

    func testTextConstraints() {
        for item in catalog.allItems {
            XCTAssertTrue((1...20).contains(item.name.count), item.id)
            XCTAssertTrue((2...6).contains(item.steps.count), item.id)
            for step in item.steps {
                XCTAssertTrue((1...60).contains(step.count), "\(item.id): \(step)")
            }
            XCTAssertEqual(item.emoji.count, 1, item.id)
        }
    }

    func testRewardItemsAreURAndRest() {
        for item in catalog.rewardItems {
            XCTAssertEqual(item.rarity, .ur, item.id)
            XCTAssertEqual(item.bodyPart, .rest, item.id)
        }
        for item in catalog.stretchItems {
            XCTAssertNotEqual(item.bodyPart, .rest, item.id)
        }
    }

    func testEveryStretchBodyPartHasAtLeastOneItem() {
        for part in BodyPart.allCases where part != .rest {
            XCTAssertFalse(catalog.items(bodyPart: part).isEmpty, part.rawValue)
        }
    }

    func testForbiddenWordsAreAbsent() {
        for item in catalog.allItems {
            let texts = [item.name] + item.steps + [item.caution ?? ""]
            for word in CatalogValidator.forbiddenWords {
                XCTAssertFalse(texts.contains { $0.contains(word) },
                               "\(item.id): 禁止語 \(word)")
            }
        }
    }

    func testItemLookup() {
        let first = catalog.allItems[0]
        XCTAssertEqual(catalog.item(id: first.id)?.id, first.id)
        XCTAssertNil(catalog.item(id: "unknown-99"))
    }

    func testGroupingSumsMatchTotalCount() {
        let byRarity = Rarity.allCases.map { catalog.items(rarity: $0).count }.reduce(0, +)
        let byPart = BodyPart.allCases.map { catalog.items(bodyPart: $0).count }.reduce(0, +)
        XCTAssertEqual(byRarity, catalog.totalCount)
        XCTAssertEqual(byPart, catalog.totalCount)
    }

    func testColdLoadFinishesWithin500ms() throws {
        let bundle = Bundle(for: StretchGacha.DailyDrawState.self)
        let start = Date()
        _ = try StretchCatalog.load(bundle: bundle)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
    }

    func testJSONFileSizeIsWithin64KB() throws {
        let bundle = Bundle(for: StretchGacha.DailyDrawState.self)
        let url = try XCTUnwrap(bundle.url(forResource: "StretchCatalog", withExtension: "json"))
        let size = try XCTUnwrap(FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? Int)
        XCTAssertLessThanOrEqual(size, 64 * 1024)
    }

    // 拡張性の実証: Swift コードを変更せずにフィクスチャの追加種目が読める
    func testFixtureWithExtraItemLoadsWithoutCodeChanges() throws {
        let fixture = try StretchCatalog.load(bundle: Bundle(for: CatalogTests.self),
                                              resource: "StretchCatalogFixture")
        XCTAssertEqual(fixture.totalCount, StretchCatalog.shared.totalCount + 1)
        let added = try XCTUnwrap(fixture.item(id: "neck-06"))
        XCTAssertEqual(added.bodyPart, .neck)
        XCTAssertTrue(fixture.items(bodyPart: .neck).contains { $0.id == "neck-06" })
    }
}
