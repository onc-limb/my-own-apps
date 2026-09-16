import Foundation
import Observation
import Week168Domain
import Week168Persistence
import Week168UseCases

@MainActor @Observable
final class ReviewViewModel {
    enum Period: String, CaseIterable { case week, month }
    private let store: Week168Store
    private let service: Week168Service
    var period: Period = .week
    private(set) var anchor: Date = .now
    private(set) var settings: CalendarSettings?
    private(set) var weeks: [ReviewWeek] = []
    private(set) var activities: [ReviewActivity] = []
    private(set) var isBusy = false
    var issue: String?

    init(store: Week168Store, service: Week168Service) { self.store = store; self.service = service }

    var title: String {
        guard let settings else { return "" }
        if period == .week, let first = weeks.first { return reviewDay(first.week.startDay) }
        let day = TimeAxis.logicalDay(of: anchor, settings: settings)
        return reviewText("review.monthTitle", day.year, day.month)
    }

    func refresh(now: Date = .now) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        issue = nil
        do {
            if try await store.loadSettings() == nil { _ = try await service.homeSections(recentLimit: 8) }
            let snapshot = try await ReviewSnapshot.load(store: store)
            settings = snapshot.settings
            let day = TimeAxis.logicalDay(of: anchor, settings: snapshot.settings)
            let selected = period == .week
                ? [TimeAxis.logicalWeek(of: day, settings: snapshot.settings)]
                : TimeAxis.weeks(inYear: day.year, month: day.month, settings: snapshot.settings)
            var reports: [ReviewWeek] = []
            for week in selected {
                let record = try await store.loadCommitment(for: week)
                reports.append(try snapshot.report(week: week, hasCommitment: record != nil, now: now))
            }
            activities = try ReviewSnapshot.combine(reports)
            weeks = reports
        } catch {
            weeks = []; activities = []
            issue = String(localized: "review.error.load")
        }
    }

    func move(_ offset: Int?, now: Date = .now) async {
        guard !isBusy, let settings else { return }
        if let offset {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: settings.timeZoneIdentifier) ?? .current
            // Anchor month movement on the logical label, avoiding month-end date clamping.
            let day = TimeAxis.logicalDay(of: anchor, settings: settings)
            let base = period == .month
                ? TimeAxis.interval(of: LogicalDay(year: day.year, month: day.month, day: 1), settings: settings).start
                : TimeAxis.interval(of: TimeAxis.logicalWeek(of: day, settings: settings), settings: settings).start
            guard let next = calendar.date(byAdding: period == .week ? .day : .month,
                value: period == .week ? offset * 7 : offset, to: base),
                (2...9998).contains(calendar.component(.year, from: next)) else { return }
            anchor = next
        } else { anchor = now }
        await refresh(now: now)
    }
}
