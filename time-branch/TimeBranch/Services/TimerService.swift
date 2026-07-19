import Foundation
import SwiftData

@MainActor
enum TimerService {
    static func activeEntry(in context: ModelContext) throws -> TimeEntry? {
        var descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    static func toggle(project: WorkProject, at date: Date = .now, in context: ModelContext) throws -> TimeEntry? {
        let current = try activeEntry(in: context)

        if current?.project?.id == project.id {
            current?.endedAt = max(date, current?.startedAt ?? date)
            try context.save()
            return nil
        }

        if let current {
            current.endedAt = max(date, current.startedAt)
        }

        let next = TimeEntry(project: project, startedAt: date)
        context.insert(next)
        try context.save()
        return next
    }

    static func stop(at date: Date = .now, in context: ModelContext) throws {
        guard let current = try activeEntry(in: context) else { return }
        current.endedAt = max(date, current.startedAt)
        try context.save()
    }
}

