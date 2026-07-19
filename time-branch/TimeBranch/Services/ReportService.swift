import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case day = "1日"
    case week = "1週間"
    case month = "1ヶ月"

    var id: Self { self }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .day:
            return calendar.dateInterval(of: .day, for: date)!
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)!
        case .month:
            return calendar.dateInterval(of: .month, for: date)!
        }
    }
}

struct ProjectTotal: Identifiable {
    let project: WorkProject
    let seconds: TimeInterval
    var id: UUID { project.id }
}

enum ReportService {
    static func totals(
        projects: [WorkProject],
        entries: [TimeEntry],
        interval: DateInterval,
        now: Date = .now
    ) -> [ProjectTotal] {
        let direct = Dictionary(grouping: entries.compactMap { entry -> (UUID, TimeInterval)? in
            guard let project = entry.project else { return nil }
            let duration = entry.overlappingDuration(from: interval.start, to: interval.end, now: now)
            return duration > 0 ? (project.id, duration) : nil
        }, by: \.0).mapValues { values in values.reduce(0) { $0 + $1.1 } }

        return projects.compactMap { project in
            let seconds = direct.reduce(0) { total, item in
                guard let recordedProject = projects.first(where: { $0.id == item.key }) else { return total }
                return recordedProject.isDescendant(of: project) ? total + item.value : total
            }
            return seconds > 0 ? ProjectTotal(project: project, seconds: seconds) : nil
        }
        .sorted { $0.seconds > $1.seconds }
    }

    static func filteredEntries(_ entries: [TimeEntry], interval: DateInterval, now: Date = .now) -> [TimeEntry] {
        entries.filter {
            $0.startedAt < interval.end && ($0.endedAt ?? now) > interval.start
        }
        .sorted { $0.startedAt > $1.startedAt }
    }
}

