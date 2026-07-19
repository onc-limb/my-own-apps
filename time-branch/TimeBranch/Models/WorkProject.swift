import Foundation
import SwiftData

@Model
final class WorkProject {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var sortOrder: Int

    var parent: WorkProject?

    @Relationship(deleteRule: .cascade, inverse: \WorkProject.parent)
    var children: [WorkProject]

    @Relationship(inverse: \DisplayPage.projects)
    var pages: [DisplayPage]

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    var entries: [TimeEntry]

    init(
        name: String,
        colorHex: String = "#4F7CAC",
        parent: WorkProject? = nil,
        sortOrder: Int = 0
    ) {
        id = UUID()
        self.name = name
        self.colorHex = colorHex
        createdAt = .now
        self.sortOrder = sortOrder
        self.parent = parent
        children = []
        pages = []
        entries = []
    }

    var sortedChildren: [WorkProject] {
        children.sorted {
            if $0.sortOrder == $1.sortOrder { return $0.name < $1.name }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var ancestorsIncludingSelf: [WorkProject] {
        var result: [WorkProject] = []
        var current: WorkProject? = self
        var seen = Set<UUID>()
        while let project = current, seen.insert(project.id).inserted {
            result.append(project)
            current = project.parent
        }
        return result
    }

    func isDescendant(of project: WorkProject) -> Bool {
        ancestorsIncludingSelf.contains { $0.id == project.id }
    }
}

