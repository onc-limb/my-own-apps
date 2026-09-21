import XCTest
@testable import StretchDraw

final class StretchDrawTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testRarityTableUsesCommonRareAndSSRBoundaries() {
        let catalog = [
            Stretch(id: "c", name: "C", instruction: "", symbol: "circle", rarity: .common),
            Stretch(id: "r", name: "R", instruction: "", symbol: "circle", rarity: .rare),
            Stretch(id: "s", name: "S", instruction: "", symbol: "circle", rarity: .ssr)
        ]

        XCTAssertEqual(DrawEngine.draw(from: catalog, streak: 0, rarityRoll: 0.71, candidateRoll: 0).rarity, .common)
        XCTAssertEqual(DrawEngine.draw(from: catalog, streak: 0, rarityRoll: 0.72, candidateRoll: 0).rarity, .rare)
        XCTAssertEqual(DrawEngine.draw(from: catalog, streak: 0, rarityRoll: 0.96, candidateRoll: 0).rarity, .ssr)
    }

    func testLockedAndClimberItemsStayOutOfGeneralDraw() {
        let result = DrawEngine.draw(
            at: date(2026, 8, 6),
            streak: 0,
            profile: .general,
            rarityRoll: 0.2,
            candidateRoll: 0.99,
            calendar: utcCalendar
        )

        XCTAssertEqual(result.profile, .general)
        XCTAssertEqual(result.unlockStreak, 0)
    }

    func testClimberProfileCanDrawClimberTable() {
        let catalog = [
            Stretch(id: "general", name: "General", instruction: "", symbol: "circle", rarity: .common),
            Stretch(id: "climber", name: "Climber", instruction: "", symbol: "circle", rarity: .common, profile: .climber)
        ]

        let result = DrawEngine.draw(
            from: catalog,
            streak: 0,
            profile: .climber,
            rarityRoll: 0.1,
            candidateRoll: 0.99
        )

        XCTAssertEqual(result.id, "climber")
    }

    func testRerollExcludesCurrentItemAndOnlyRunsOnce() {
        let first = Stretch(id: "first", name: "First", instruction: "", symbol: "circle", rarity: .common)
        let second = Stretch(id: "second", name: "Second", instruction: "", symbol: "circle", rarity: .common)
        let record = DailyDraw(stretch: first)
        let replacement = DrawEngine.draw(
            from: [first, second],
            streak: 0,
            excluding: first.id,
            rarityRoll: 0.1,
            candidateRoll: 0
        )

        record.replace(with: replacement)
        record.replace(with: first)

        XCTAssertEqual(record.stretchID, second.id)
        XCTAssertEqual(record.rerollCount, 1)
        XCTAssertFalse(record.canReroll)
    }

    func testStreakCountsThroughYesterdayUntilTodayIsCompleted() {
        let stretch = Stretch(id: "stretch", name: "Stretch", instruction: "", symbol: "circle", rarity: .common)
        let yesterday = DailyDraw(stretch: stretch, drawnAt: date(2026, 8, 5), completed: true)
        let twoDaysAgo = DailyDraw(stretch: stretch, drawnAt: date(2026, 8, 4), completed: true)
        let today = DailyDraw(stretch: stretch, drawnAt: date(2026, 8, 6))

        XCTAssertEqual(
            StreakService.currentStreak(
                records: [today, yesterday, twoDaysAgo],
                today: date(2026, 8, 6),
                calendar: utcCalendar
            ),
            2
        )

        today.complete(at: date(2026, 8, 6, hour: 13))
        XCTAssertEqual(
            StreakService.currentStreak(
                records: [today, yesterday, twoDaysAgo],
                today: date(2026, 8, 6),
                calendar: utcCalendar
            ),
            3
        )
    }
}
