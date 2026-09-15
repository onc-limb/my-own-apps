import Foundation
import Testing
import Week168Domain

@Suite("時間の基礎", .serialized)
struct TimeAxisTests {
    private let tokyo = CalendarSettings(
        timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: 2
    )

    private func instant(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> LogicalDay {
        LogicalDay(year: year, month: month, day: day)
    }

    private func span(_ start: String, _ end: String) -> DateInterval {
        DateInterval(start: instant(start), end: instant(end))
    }

    @Test("01: 03:59 は前日の論理日")
    func beforeDayStart() {
        #expect(TimeAxis.logicalDay(of: instant("2026-09-15T03:59:00+09:00"), settings: tokyo) == day(2026, 9, 14))
    }

    @Test("02: 04:00 は当日の論理日")
    func atDayStart() {
        #expect(TimeAxis.logicalDay(of: instant("2026-09-15T04:00:00+09:00"), settings: tokyo) == day(2026, 9, 15))
    }

    @Test("03: 23:59 は当日の論理日")
    func lateInDay() {
        #expect(TimeAxis.logicalDay(of: instant("2026-09-15T23:59:00+09:00"), settings: tokyo) == day(2026, 9, 15))
    }

    @Test("04: 0 時始まりの 00:00")
    func midnightDayStart() {
        var settings = tokyo
        settings.dayStartHour = 0
        #expect(TimeAxis.logicalDay(of: instant("2026-09-15T00:00:00+09:00"), settings: settings) == day(2026, 9, 15))
    }

    @Test("05: 月曜は同日の週に属する")
    func mondayWeekStart() {
        #expect(TimeAxis.logicalWeek(of: day(2026, 9, 14), settings: tokyo).startDay == day(2026, 9, 14))
    }

    @Test("06: 日曜は直前の月曜の週に属する")
    func sundayInMondayWeek() {
        #expect(TimeAxis.logicalWeek(of: day(2026, 9, 13), settings: tokyo).startDay == day(2026, 9, 7))
    }

    @Test("07: 日曜始まりの日曜")
    func sundayWeekStart() {
        var settings = tokyo
        settings.weekStartWeekday = 1
        #expect(TimeAxis.logicalWeek(of: day(2026, 9, 13), settings: settings).startDay == day(2026, 9, 13))
    }

    @Test("08: 9 月には 9/7・14・21・28 開始の 4 週だけが属する")
    func weeksStartingInSeptember() {
        let weeks = TimeAxis.weeks(inYear: 2026, month: 9, settings: tokyo)
        #expect(weeks.map(\.startDay) == [7, 14, 21, 28].map { day(2026, 9, $0) })
    }

    @Test("09: プロセス既定 TZ を変更しても論理日・週・期間は一致する")
    func independentOfDefaultTimeZone() {
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        let value = instant("2026-09-15T04:00:00+09:00")
        NSTimeZone.default = TimeZone(identifier: "Asia/Tokyo")!
        let logicalDay = TimeAxis.logicalDay(of: value, settings: tokyo)
        let week = TimeAxis.logicalWeek(of: logicalDay, settings: tokyo)
        let dayInterval = TimeAxis.interval(of: logicalDay, settings: tokyo)
        let weekInterval = TimeAxis.interval(of: week, settings: tokyo)
        let monthWeeks = TimeAxis.weeks(inYear: 2026, month: 9, settings: tokyo)
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        #expect(NSTimeZone.default.identifier == "America/New_York")
        let changedDay = TimeAxis.logicalDay(of: value, settings: tokyo)
        let changedWeek = TimeAxis.logicalWeek(of: changedDay, settings: tokyo)
        #expect(changedDay == logicalDay)
        #expect(changedWeek == week)
        #expect(TimeAxis.interval(of: changedDay, settings: tokyo) == dayInterval)
        #expect(TimeAxis.interval(of: changedWeek, settings: tokyo) == weekInterval)
        #expect(TimeAxis.weeks(inYear: 2026, month: 9, settings: tokyo) == monthWeeks)
    }

    private var range: DateInterval {
        span("2026-09-15T10:00:00Z", "2026-09-15T11:00:00Z")
    }

    @Test("10: 記録が範囲内に収まる")
    func containedEntry() {
        let entry = span("2026-09-15T10:10:00Z", "2026-09-15T10:40:00Z")
        #expect(TimeAxis.overlappingMinutes(of: entry, within: range) == 30)
    }

    @Test("11: 記録が範囲を覆う")
    func coveringEntry() {
        let entry = span("2026-09-15T09:00:00Z", "2026-09-15T12:00:00Z")
        #expect(TimeAxis.overlappingMinutes(of: entry, within: range) == 60)
    }

    @Test("12: 前方・後方にはみ出す記録の重なり")
    func partiallyOverlappingEntries() {
        let early = span("2026-09-15T09:30:00Z", "2026-09-15T10:20:00Z")
        let late = span("2026-09-15T10:45:00Z", "2026-09-15T11:30:00Z")
        #expect(TimeAxis.overlappingMinutes(of: early, within: range) == 20)
        #expect(TimeAxis.overlappingMinutes(of: late, within: range) == 15)
    }

    @Test("13: 重ならない記録")
    func disjointEntries() {
        let early = span("2026-09-15T08:00:00Z", "2026-09-15T09:00:00Z")
        let late = span("2026-09-15T12:00:00Z", "2026-09-15T13:00:00Z")
        #expect(TimeAxis.overlappingMinutes(of: early, within: range) == 0)
        #expect(TimeAxis.overlappingMinutes(of: late, within: range) == 0)
    }

    @Test("14: 隣接する期間は重ならない")
    func adjacentEntries() {
        let early = span("2026-09-15T09:00:00Z", "2026-09-15T10:00:00Z")
        let late = span("2026-09-15T11:00:00Z", "2026-09-15T12:00:00Z")
        #expect(TimeAxis.overlappingMinutes(of: early, within: range) == 0)
        #expect(TimeAxis.overlappingMinutes(of: late, within: range) == 0)
    }

    @Test("15: 長さ 0 の記録")
    func emptyEntry() {
        let entry = span("2026-09-15T10:30:00Z", "2026-09-15T10:30:00Z")
        #expect(TimeAxis.overlappingMinutes(of: entry, within: range) == 0)
        #expect(TimeAxis.overlappingMinutes(of: range, within: entry) == 0)
    }

    @Test("16: 翌日の開始は当日の終了と一致する")
    func consecutiveDayIntervals() {
        let first = TimeAxis.interval(of: day(2026, 9, 15), settings: tokyo)
        let next = TimeAxis.interval(of: day(2026, 9, 16), settings: tokyo)
        #expect(first == span("2026-09-15T04:00:00+09:00", "2026-09-16T04:00:00+09:00"))
        #expect(first.end == next.start)
        #expect(TimeAxis.logicalDay(of: first.end, settings: tokyo) == day(2026, 9, 16))
        #expect(TimeAxis.overlappingMinutes(of: first, within: next) == 0)
    }

    @Test("17: 週は 7 日分の論理日を過不足なく覆う")
    func weekCoversSevenDays() {
        assertWeek(year: 2026, month: 9, startDay: 14, settings: tokyo, expectedHours: 168)
    }

    private func assertWeek(year: Int, month: Int, startDay: Int, settings: CalendarSettings, expectedHours: Int) {
        let week = LogicalWeek(startDay: day(year, month, startDay))
        let interval = TimeAxis.interval(of: week, settings: settings)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = calendar.date(from: DateComponents(year: year, month: month, day: startDay))!
        let days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: first)!
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return TimeAxis.interval(of: day(components.year!, components.month!, components.day!), settings: settings)
        }
        #expect(interval.start == days.first!.start)
        #expect(interval.end == days.last!.end)
        for index in 0..<6 {
            #expect(days[index].end == days[index + 1].start)
        }
        #expect(days.reduce(0) { $0 + $1.duration } == interval.duration)
        #expect(interval.duration == Double(expectedHours * 60 * 60))
    }

    @Test("夏時間の開始・終了では 23 時間・25 時間の日になる")
    func daylightSavingDayLengths() {
        let settings = CalendarSettings(timeZoneIdentifier: "America/New_York", dayStartHour: 4, weekStartWeekday: 2)
        let spring = TimeAxis.interval(of: day(2026, 3, 7), settings: settings)
        let autumn = TimeAxis.interval(of: day(2026, 10, 31), settings: settings)
        #expect(spring == span("2026-03-07T04:00:00-05:00", "2026-03-08T04:00:00-04:00"))
        #expect(autumn == span("2026-10-31T04:00:00-04:00", "2026-11-01T04:00:00-05:00"))
        #expect(spring.duration == 23 * 60 * 60)
        #expect(autumn.duration == 25 * 60 * 60)
        #expect(spring.end == TimeAxis.interval(of: day(2026, 3, 8), settings: settings).start)
        #expect(autumn.end == TimeAxis.interval(of: day(2026, 11, 1), settings: settings).start)
        #expect(TimeAxis.logicalDay(of: instant("2026-03-08T04:00:00-04:00"), settings: settings) == day(2026, 3, 8))
        #expect(TimeAxis.logicalDay(of: instant("2026-11-01T03:59:00-05:00"), settings: settings) == day(2026, 10, 31))
    }

    @Test("夏時間を含む週は 167 時間・169 時間になる")
    func daylightSavingWeekLengths() {
        let settings = CalendarSettings(timeZoneIdentifier: "America/New_York", dayStartHour: 0, weekStartWeekday: 2)
        assertWeek(year: 2026, month: 3, startDay: 2, settings: settings, expectedHours: 167)
        assertWeek(year: 2026, month: 10, startDay: 26, settings: settings, expectedHours: 169)
    }

    @Test("存在しない開始時刻は次の有効時刻に進む")
    func missingDayStart() {
        let settings = CalendarSettings(timeZoneIdentifier: "America/New_York", dayStartHour: 2, weekStartWeekday: 2)
        let interval = TimeAxis.interval(of: day(2026, 3, 8), settings: settings)
        #expect(interval.start == instant("2026-03-08T03:00:00-04:00"))
        #expect(TimeAxis.logicalDay(of: interval.start.addingTimeInterval(-1), settings: settings) == day(2026, 3, 7))
        #expect(TimeAxis.logicalDay(of: interval.start, settings: settings) == day(2026, 3, 8))
        #expect(interval.end == TimeAxis.interval(of: day(2026, 3, 9), settings: settings).start)
    }

    @Test("重複する開始時刻は最初の時刻を使う")
    func repeatedDayStart() {
        let settings = CalendarSettings(timeZoneIdentifier: "America/New_York", dayStartHour: 1, weekStartWeekday: 2)
        let interval = TimeAxis.interval(of: day(2026, 11, 1), settings: settings)
        #expect(interval.start == instant("2026-11-01T01:00:00-04:00"))
        #expect(TimeAxis.logicalDay(of: interval.start.addingTimeInterval(-1), settings: settings) == day(2026, 10, 31))
        #expect(TimeAxis.logicalDay(of: instant("2026-11-01T01:00:00-05:00"), settings: settings) == day(2026, 11, 1))
        #expect(interval.end == TimeAxis.interval(of: day(2026, 11, 2), settings: settings).start)
    }

    @Test("単一期間の分表示用の便宜関数は分未満を切り捨てる")
    func fractionalMinutes() {
        let short = span("2026-09-15T10:00:00Z", "2026-09-15T10:00:59Z")
        let longer = span("2026-09-15T09:59:30Z", "2026-09-15T10:01:59Z")
        #expect(TimeAxis.overlappingMinutes(of: short, within: range) == 0)
        #expect(TimeAxis.overlappingMinutes(of: longer, within: range) == 1)
    }

    @Test("F-1: 秒の重なりは部分重複・包含・隣接・空期間を扱う")
    func overlappingSeconds() {
        let start = range.start
        let contained = DateInterval(start: start.addingTimeInterval(10), duration: 90.5)
        let covering = DateInterval(start: start.addingTimeInterval(-10), end: range.end.addingTimeInterval(10))
        let early = DateInterval(start: start.addingTimeInterval(-30), duration: 60.5)
        let late = DateInterval(start: range.end.addingTimeInterval(-20.25), duration: 30)
        #expect(TimeAxis.overlappingSeconds(of: contained, within: range) == 90.5)
        #expect(TimeAxis.overlappingSeconds(of: covering, within: range) == 3600)
        #expect(TimeAxis.overlappingSeconds(of: early, within: range) == 30.5)
        #expect(TimeAxis.overlappingSeconds(of: late, within: range) == 20.25)
        #expect(TimeAxis.overlappingSeconds(of: DateInterval(start: start.addingTimeInterval(-60), duration: 60), within: range) == 0)
        #expect(TimeAxis.overlappingSeconds(of: DateInterval(start: range.end, duration: 60), within: range) == 0)
        #expect(TimeAxis.overlappingSeconds(of: DateInterval(start: range.end.addingTimeInterval(1), duration: 60), within: range) == 0)
        let empty = DateInterval(start: start.addingTimeInterval(30), duration: 0)
        #expect(TimeAxis.overlappingSeconds(of: empty, within: range) == 0)
        #expect(TimeAxis.overlappingSeconds(of: range, within: empty) == 0)
    }

    @Test("F-1: 90 秒の記録 10 件を秒で合計すると 15 分になる")
    func accumulateSecondsBeforeConvertingToMinutes() {
        let entries = (0..<10).map { offset in
            DateInterval(start: range.start.addingTimeInterval(Double(offset) * 90), duration: 90)
        }
        let totalSeconds = entries.reduce(0.0) { $0 + TimeAxis.overlappingSeconds(of: $1, within: range) }
        #expect(totalSeconds == 900)
        #expect(Int(totalSeconds / 60) == 15)
    }

    @Test("F-1: 小数秒を含む記録も丸めず累積する")
    func accumulateFractionalSeconds() {
        let entries = (0..<120).map { offset in
            DateInterval(start: range.start.addingTimeInterval(Double(offset)), duration: 0.5)
        }
        let totalSeconds = entries.reduce(0.0) { $0 + TimeAxis.overlappingSeconds(of: $1, within: range) }
        #expect(totalSeconds == 60)
        #expect(Int(totalSeconds / 60) == 1)
    }

    @Test("F-2: 範囲外の開始時刻は値を含むエラーを返す")
    func rejectInvalidDayStartHour() {
        for hour in [-1, 7] {
            #expect(throws: CalendarSettings.ValidationError.dayStartHourOutOfRange(hour)) {
                try CalendarSettings.validated(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: hour, weekStartWeekday: 2)
            }
        }
    }

    @Test("F-2: 範囲外の週開始曜日は値を含むエラーを返す")
    func rejectInvalidWeekStartWeekday() {
        for weekday in [0, 8] {
            #expect(throws: CalendarSettings.ValidationError.weekStartWeekdayOutOfRange(weekday)) {
                try CalendarSettings.validated(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: weekday)
            }
        }
    }

    @Test("F-2: 不明・空のタイムゾーンは値を含むエラーを返す")
    func rejectUnknownTimeZone() {
        for identifier in ["Unknown/Zone", ""] {
            #expect(throws: CalendarSettings.ValidationError.unknownTimeZone(identifier)) {
                try CalendarSettings.validated(timeZoneIdentifier: identifier, dayStartHour: 4, weekStartWeekday: 2)
            }
        }
    }

    @Test("F-2・F-3: 有効な設定の境界値と全曜日で論理週の動作を保つ")
    func validatedSettingsAndLogicalWeeks() throws {
        let expectedStartDays = [13, 7, 8, 9, 10, 11, 12]
        for hour in [0, 6] {
            for weekday in 1...7 {
                let settings = try CalendarSettings.validated(
                    timeZoneIdentifier: "Asia/Tokyo", dayStartHour: hour, weekStartWeekday: weekday
                )
                #expect(settings == CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: hour, weekStartWeekday: weekday))
                #expect(TimeAxis.logicalWeek(of: day(2026, 9, 13), settings: settings).startDay == day(2026, 9, expectedStartDays[weekday - 1]))
            }
        }
    }

    @Test("年末・閏日の境界と月の最初・最後の週")
    func calendarRollovers() {
        #expect(TimeAxis.interval(of: day(2026, 12, 31), settings: tokyo).end == TimeAxis.interval(of: day(2027, 1, 1), settings: tokyo).start)
        #expect(TimeAxis.interval(of: day(2024, 2, 29), settings: tokyo).end == TimeAxis.interval(of: day(2024, 3, 1), settings: tokyo).start)
        #expect(TimeAxis.logicalWeek(of: day(2027, 1, 1), settings: tokyo).startDay == day(2026, 12, 28))
        #expect(TimeAxis.weeks(inYear: 2026, month: 6, settings: tokyo).map(\.startDay) == [1, 8, 15, 22, 29].map { day(2026, 6, $0) })
        #expect(TimeAxis.weeks(inYear: 2026, month: 12, settings: tokyo).map(\.startDay) == [7, 14, 21, 28].map { day(2026, 12, $0) })
    }

    @Test("日・週の比較とハッシュ、設定の値等価性")
    func valueSemantics() {
        let days = [day(2027, 1, 1), day(2026, 10, 1), day(2026, 9, 30), day(2026, 9, 29)]
        #expect(days.sorted() == Array(days.reversed()))
        #expect(Set([days[0], days[0]]).count == 1)
        let weeks = days.map { LogicalWeek(startDay: $0) }
        #expect(weeks.sorted() == Array(weeks.reversed()))
        #expect(Set([weeks[0], weeks[0]]).count == 1)
        #expect(tokyo == CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: 2))
    }
}
