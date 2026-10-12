import XCTest
@testable import StretchGacha

final class StretchCardTests: XCTestCase {

    private func item(id: String = "test-01",
                      name: String = "テスト種目",
                      kind: ItemKind = .stretch,
                      bodyPart: BodyPart = .neck,
                      rarity: Rarity = .n,
                      duration: Int = 60,
                      emoji: String = "🙆",
                      steps: [String] = ["手順1", "手順2"],
                      caution: String? = nil) -> StretchItem {
        StretchItem(id: id, name: name, kind: kind, bodyPart: bodyPart, rarity: rarity,
                    durationSeconds: duration, emoji: emoji, steps: steps, caution: caution)
    }

    // MARK: - DurationLabel（経路差で揺れない値は厳密にアサートする）

    func testDurationLabelExactValues() {
        XCTAssertEqual(DurationLabel.text(seconds: 20), "20秒")
        XCTAssertEqual(DurationLabel.text(seconds: 45), "45秒")
        XCTAssertEqual(DurationLabel.text(seconds: 59), "59秒")
        XCTAssertEqual(DurationLabel.text(seconds: 60), "1分")
        XCTAssertEqual(DurationLabel.text(seconds: 75), "1分15秒")
        XCTAssertEqual(DurationLabel.text(seconds: 90), "1分30秒")
    }

    // MARK: - make(from:) の防御的処理

    func testEmojiIsTruncatedToFirstCharacter() {
        let content = StretchCardContent.make(from: item(emoji: "🙆🙆"))
        XCTAssertEqual(content.emoji, "🙆")
    }

    func testEmptyEmojiDoesNotCrash() {
        let content = StretchCardContent.make(from: item(emoji: ""))
        XCTAssertEqual(content.emoji, "")
    }

    func testBlankStepsAreRemoved() {
        let content = StretchCardContent.make(from: item(steps: ["  ", "手順A", "\n", "手順B "]))
        XCTAssertEqual(content.steps, ["手順A", "手順B"])
    }

    func testEmptyStepsProduceEmptyArray() {
        let content = StretchCardContent.make(from: item(steps: []))
        XCTAssertEqual(content.steps, [])
    }

    func testCautionBlankBecomesNil() {
        XCTAssertNil(StretchCardContent.make(from: item(caution: nil)).caution)
        XCTAssertNil(StretchCardContent.make(from: item(caution: "")).caution)
        XCTAssertNil(StretchCardContent.make(from: item(caution: "  \n")).caution)
        XCTAssertEqual(StretchCardContent.make(from: item(caution: " 注意 ")).caution, "注意")
    }

    func testNonPositiveDurationHidesDurationText() {
        XCTAssertNil(StretchCardContent.make(from: item(duration: 0)).durationText)
        XCTAssertNil(StretchCardContent.make(from: item(duration: -5)).durationText)
        XCTAssertEqual(StretchCardContent.make(from: item(duration: 60)).durationText, "1分")
    }

    func testEmptyNameDoesNotCrash() {
        let content = StretchCardContent.make(from: item(name: ""))
        XCTAssertEqual(content.name, "")
    }

    func testAllBundledItemsProduceNonEmptyDerivedValues() {
        for bundled in StretchCatalog.shared.allItems {
            let content = StretchCardContent.make(from: bundled)
            XCTAssertFalse(content.rarityLabel.isEmpty, bundled.id)
            XCTAssertFalse(content.bodyPartLabel.isEmpty, bundled.id)
            XCTAssertNotNil(content.durationText, bundled.id)
        }
    }

    func testRewardUsesSameCodePathAsStretch() {
        // reward 専用の分岐が無いことの検証: 同じ経路で同じ派生値の形になる
        for reward in StretchCatalog.shared.rewardItems {
            let content = StretchCardContent.make(from: reward)
            XCTAssertEqual(content.rarityLabel, "UR")
            XCTAssertEqual(content.bodyPartLabel, BodyPart.rest.displayName)
        }
    }

    // MARK: - RarityStyle

    func testRarityStyleCoversAllCases() {
        for rarity in Rarity.allCases {
            _ = RarityStyle.accentRGB(for: rarity)
            XCTAssertFalse(rarity.displayName.isEmpty)
        }
    }

    // WCAG の相対輝度式でコントラスト比を実測し、8 組すべてで 4.5 以上をアサートする
    func testBadgeContrastIsAtLeast4_5ForAllCombinations() {
        for rarity in Rarity.allCases {
            let accents = RarityStyle.accentRGB(for: rarity)
            let fg = RarityStyle.badgeForegroundRGB
            for (accent, foreground) in [(accents.light, fg.light), (accents.dark, fg.dark)] {
                let ratio = contrastRatio(accent, foreground)
                XCTAssertGreaterThanOrEqual(ratio, 4.5,
                    "\(rarity.rawValue): \(String(accent, radix: 16)) vs \(String(foreground, radix: 16)) = \(ratio)")
            }
        }
    }

    private func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let (lighter, darker) = la > lb ? (la, lb) : (lb, la)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ rgb: UInt32) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = AdaptiveColor.components(rgb)
        return 0.2126 * linear(Double(r)) + 0.7152 * linear(Double(g)) + 0.0722 * linear(Double(b))
    }

    // MARK: - 性能

    func testMakePerformance10kWithin2Seconds() {
        let sample = StretchCatalog.shared.allItems[0]
        let start = Date()
        for _ in 0..<10_000 {
            _ = StretchCardContent.make(from: sample)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    // 拡張性の実証: フィクスチャの追加種目に対しても Card 側は無変更で正しい派生値を返す
    func testFixtureExtraItemProducesCorrectDerivedValues() throws {
        let fixture = try StretchCatalog.load(bundle: Bundle(for: StretchCardTests.self),
                                              resource: "StretchCatalogFixture")
        let added = try XCTUnwrap(fixture.item(id: "neck-06"))
        let content = StretchCardContent.make(from: added)
        XCTAssertEqual(content.bodyPartLabel, BodyPart.neck.displayName)
        XCTAssertEqual(content.durationText, "30秒")
    }
}
