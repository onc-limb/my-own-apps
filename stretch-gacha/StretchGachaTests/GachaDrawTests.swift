import XCTest
import SwiftData
@testable import StretchGacha

final class GachaDrawTests: XCTestCase {

    private let catalog = StretchCatalog.shared

    private func drawMany(count: Int,
                          seed: UInt64,
                          owned: Set<String> = [],
                          drawnToday: Set<String> = []) -> [StretchItem] {
        var rng = SeededRandomGenerator(seed: seed)
        let context = DrawContext(catalog: catalog,
                                  ownedItemIDs: owned,
                                  drawnTodayItemIDs: drawnToday)
        return (0..<count).map { _ in GachaDrawer.draw(context, using: &rng) }
    }

    // MARK: - 決定性・分布

    func testSameSeedReproducesSameSequence() {
        let a = drawMany(count: 100, seed: 42).map(\.id)
        let b = drawMany(count: 100, seed: 42).map(\.id)
        XCTAssertEqual(a, b)
    }

    func testRarityDistributionWithin20PercentRelative() {
        let n = 100_000
        let results = drawMany(count: n, seed: 1)
        let counts = Dictionary(grouping: results, by: \.rarity).mapValues(\.count)
        for rarity in Rarity.allCases {
            let expected = Double(n) * Double(catalog.weight(for: rarity)) / 100
            let actual = Double(counts[rarity] ?? 0)
            XCTAssertTrue(abs(actual - expected) / expected <= 0.2,
                          "\(rarity.rawValue): expected \(expected), actual \(actual)")
        }
    }

    func testUniformWithinRarityWhenNothingOwned() {
        let n = 100_000
        let results = drawMany(count: n, seed: 2)
        let nItems = catalog.items(rarity: .n)
        let counts = Dictionary(grouping: results.filter { $0.rarity == .n }, by: \.id)
            .mapValues(\.count)
        let expected = Double(n) * Double(catalog.weight(for: .n)) / 100 / Double(nItems.count)
        for item in nItems {
            let actual = Double(counts[item.id] ?? 0)
            XCTAssertTrue(abs(actual - expected) / expected <= 0.2,
                          "\(item.id): expected \(expected), actual \(actual)")
        }
    }

    func testUnownedItemsAppearRoughlyTwiceAsOften() {
        let nItems = catalog.items(rarity: .n)
        let owned = Set(nItems.prefix(4).map(\.id))
        let results = drawMany(count: 100_000, seed: 3, owned: owned)
        let counts = Dictionary(grouping: results.filter { $0.rarity == .n }, by: \.id)
            .mapValues(\.count)
        let ownedAvg = Double(owned.map { counts[$0] ?? 0 }.reduce(0, +)) / Double(owned.count)
        let unownedIDs = nItems.map(\.id).filter { !owned.contains($0) }
        let unownedAvg = Double(unownedIDs.map { counts[$0] ?? 0 }.reduce(0, +))
            / Double(unownedIDs.count)
        let ratio = unownedAvg / ownedAvg
        XCTAssertTrue((1.6...2.4).contains(ratio), "ratio: \(ratio)")
    }

    func testOwnershipBoostDoesNotAffectRarityTotals() {
        let owned = Set(catalog.items(rarity: .n).prefix(4).map(\.id))
        let n = 100_000
        let results = drawMany(count: n, seed: 4, owned: owned)
        let counts = Dictionary(grouping: results, by: \.rarity).mapValues(\.count)
        for rarity in Rarity.allCases {
            let expected = Double(n) * Double(catalog.weight(for: rarity)) / 100
            let actual = Double(counts[rarity] ?? 0)
            XCTAssertTrue(abs(actual - expected) / expected <= 0.2, rarity.rawValue)
        }
    }

    // MARK: - 同日重複回避

    func testDailyDedupReturnsTheOnlyRemainingItem() {
        let srItems = catalog.items(rarity: .sr)
        let drawn = Set(srItems.prefix(srItems.count - 1).map(\.id))
        let remaining = srItems.last!.id
        let results = drawMany(count: 50_000, seed: 5, drawnToday: drawn)
        for item in results where item.rarity == .sr {
            XCTAssertEqual(item.id, remaining)
        }
        XCTAssertTrue(results.contains { $0.rarity == .sr })
    }

    func testDailyDedupIsLiftedWhenAllDrawn() {
        let drawn = Set(catalog.items(rarity: .sr).map(\.id))
        let results = drawMany(count: 50_000, seed: 6, drawnToday: drawn)
        let srIDs = Set(results.filter { $0.rarity == .sr }.map(\.id))
        XCTAssertEqual(srIDs, drawn)   // 解除されて 4 件全部から出る
    }

    func testNoPitySystem_consecutiveDuplicatesCanHappen() {
        // 未入手が残っていても、確定で未入手が返る天井処理が無いことを示す:
        // 1 件だけ入手済みでも、その 1 件が連続して出る並びが十分な試行の中に存在する
        let results = drawMany(count: 100_000, seed: 7)
        var foundConsecutiveDuplicate = false
        for i in 1..<results.count where results[i].id == results[i - 1].id {
            foundConsecutiveDuplicate = true
            break
        }
        XCTAssertTrue(foundConsecutiveDuplicate)
    }

    func testDrawSpeed100kWithin2Seconds() {
        let start = Date()
        _ = drawMany(count: 100_000, seed: 8)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    // MARK: - DailyDrawStore（in-memory SwiftData）

    @MainActor
    private func makeStore(now: @escaping () -> Date) throws -> (DailyDrawStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyDrawState.self, PracticeRecord.self,
                                           configurations: config)
        let context = container.mainContext
        return (DailyDrawStore(context: context, now: now), context)
    }

    @MainActor
    func testDailyDrawStateNeverExceedsOneRow() throws {
        var day = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, context) = try makeStore(now: { day })
        for i in 0..<12 {
            _ = store.loadDrawnTodayIDs(validAgainst: catalog)
            store.recordInMemory(itemID: catalog.allItems[i % catalog.totalCount].id)
            store.flush()
            day = day.addingTimeInterval(86_400)   // 日をまたぐ
        }
        let rows = try context.fetch(FetchDescriptor<DailyDrawState>())
        XCTAssertLessThanOrEqual(rows.count, 1)
    }

    @MainActor
    func testStaleDayKeyIsResetOnLoad() throws {
        var now = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, context) = try makeStore(now: { now })
        _ = store.loadDrawnTodayIDs(validAgainst: catalog)
        store.recordInMemory(itemID: catalog.allItems[0].id)
        store.flush()
        now = now.addingTimeInterval(86_400)
        let ids = store.loadDrawnTodayIDs(validAgainst: catalog)
        XCTAssertTrue(ids.isEmpty)
        let rows = try context.fetch(FetchDescriptor<DailyDrawState>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].drawnItemIDs, [])
    }

    @MainActor
    func testUnknownIDsInPersistedStateAreIgnored() throws {
        let now = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, context) = try makeStore(now: { now })
        let row = DailyDrawState(dayKey: DailyDrawStore.dayKey(for: now),
                                 drawnItemIDs: ["ghost-99", catalog.allItems[0].id],
                                 updatedAt: now)
        context.insert(row)
        try context.save()
        let ids = store.loadDrawnTodayIDs(validAgainst: catalog)
        XCTAssertEqual(ids, [catalog.allItems[0].id])
    }

    // MARK: - GachaViewModel の状態機械

    @MainActor
    func testSpinIsIgnoredWhilePerforming() throws {
        let (store, _) = try makeStore(now: { Date() })
        _ = store.loadDrawnTodayIDs(validAgainst: catalog)
        var seed: UInt64 = 0
        let vm = GachaViewModel(catalog: catalog,
                                ownership: EmptyOwnershipProvider(),
                                store: store,
                                makeRNG: { seed += 1; return SeededRandomGenerator(seed: seed) },
                                fireHaptic: {})
        vm.spin()
        guard case .performing(let outcome) = vm.phase else {
            return XCTFail("performing でない")
        }
        vm.spin()   // 演出中の連打は無視される
        guard case .performing(let after) = vm.phase else {
            return XCTFail("performing でない")
        }
        XCTAssertEqual(outcome, after)
    }

    @MainActor
    func testSkipRevealsTheSameItemImmediately() throws {
        let (store, _) = try makeStore(now: { Date() })
        _ = store.loadDrawnTodayIDs(validAgainst: catalog)
        let vm = GachaViewModel(catalog: catalog,
                                ownership: EmptyOwnershipProvider(),
                                store: store,
                                makeRNG: { SeededRandomGenerator(seed: 9) },
                                fireHaptic: {})
        vm.spin()
        guard case .performing(let outcome) = vm.phase else {
            return XCTFail("performing でない")
        }
        vm.skip()
        guard case .revealed(let item) = vm.phase else {
            return XCTFail("revealed でない")
        }
        XCTAssertEqual(item, outcome.item)
    }

    @MainActor
    func testHapticFiresOnlyForHighlightedRarities() throws {
        let (store, _) = try makeStore(now: { Date() })
        _ = store.loadDrawnTodayIDs(validAgainst: catalog)
        var hapticCount = 0
        var seed: UInt64 = 0
        let vm = GachaViewModel(catalog: catalog,
                                ownership: EmptyOwnershipProvider(),
                                store: store,
                                makeRNG: { seed += 1; return SeededRandomGenerator(seed: seed) },
                                fireHaptic: { hapticCount += 1 })
        for _ in 0..<200 {
            vm.spin()
            guard case .performing(let outcome) = vm.phase else {
                return XCTFail("performing でない")
            }
            let before = hapticCount
            vm.hapticMomentReached()
            vm.hapticMomentReached()   // 再入しても 1 回だけ
            let fired = hapticCount - before
            XCTAssertEqual(fired, outcome.isHighlighted ? 1 : 0)
            vm.skip()
        }
    }

    @MainActor
    func testEmptyOwnershipDegradesToUniform() {
        // 空集合なら全種目が重み 2 で均等に縮退する（比 1.0 付近）
        let pool = catalog.items(rarity: .n)
        var rng = SeededRandomGenerator(seed: 10)
        var counts: [String: Int] = [:]
        for _ in 0..<50_000 {
            let item = GachaDrawer.selectItemWithOwnershipBoost(pool: pool, owned: [],
                                                               using: &rng)
            counts[item.id, default: 0] += 1
        }
        let expected = 50_000.0 / Double(pool.count)
        for item in pool {
            let actual = Double(counts[item.id] ?? 0)
            XCTAssertTrue(abs(actual - expected) / expected <= 0.2, item.id)
        }
    }
}
