import Foundation
import SwiftData

@MainActor
enum TimerService {
    static func activeEntries(in context: ModelContext) throws -> [TimeEntry] {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    static func activeEntry(in context: ModelContext) throws -> TimeEntry? {
        try activeEntries(in: context).first
    }

    @discardableResult
    static func toggle(project: WorkProject, at date: Date = .now, in context: ModelContext) throws -> TimeEntry? {
        let activeEntries = try activeEntries(in: context)
        let isStoppingSelectedProject = activeEntries.contains { $0.project?.id == project.id }

        for entry in activeEntries {
            entry.endedAt = max(date, entry.startedAt)
        }

        if isStoppingSelectedProject {
            try context.save()
            return nil
        }

        let next = TimeEntry(project: project, startedAt: date)
        context.insert(next)
        try context.save()
        return next
    }

    static func stop(at date: Date = .now, in context: ModelContext) throws {
        let activeEntries = try activeEntries(in: context)
        guard !activeEntries.isEmpty else { return }
        for entry in activeEntries {
            entry.endedAt = max(date, entry.startedAt)
        }
        try context.save()
    }
}
