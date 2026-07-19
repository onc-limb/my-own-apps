import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ExportPayload: Codable {
    struct Period: Codable {
        let from: Date
        let to: Date
    }

    struct Total: Codable {
        let projectID: UUID
        let projectName: String
        let parentProjectID: UUID?
        let seconds: Double
    }

    struct Entry: Codable {
        let id: UUID
        let projectID: UUID
        let projectName: String
        let startedAt: Date
        let endedAt: Date?
        let seconds: Double
        let note: String
    }

    let exportedAt: Date
    let period: Period
    let totals: [Total]
    let entries: [Entry]
}

struct JSONExportFile: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            file.data
        }
        .suggestedFileName { file in file.filename }
    }
}

enum ExportService {
    static func makeFile(
        totals: [ProjectTotal],
        entries: [TimeEntry],
        interval: DateInterval,
        now: Date = .now
    ) throws -> JSONExportFile {
        let payload = ExportPayload(
            exportedAt: now,
            period: .init(from: interval.start, to: interval.end),
            totals: totals.map {
                .init(
                    projectID: $0.project.id,
                    projectName: $0.project.name,
                    parentProjectID: $0.project.parent?.id,
                    seconds: $0.seconds
                )
            },
            entries: entries.compactMap { entry in
                guard let project = entry.project else { return nil }
                return .init(
                    id: entry.id,
                    projectID: project.id,
                    projectName: project.name,
                    startedAt: entry.startedAt,
                    endedAt: entry.endedAt,
                    seconds: entry.duration(until: now),
                    note: entry.note
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return JSONExportFile(data: data, filename: "time-branch-\(formatter.string(from: now)).json")
    }
}
