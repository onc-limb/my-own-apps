import Foundation
import SwiftData

@Model
final class DisplayPage {
    var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship
    var projects: [WorkProject]

    init(name: String, sortOrder: Int = 0, projects: [WorkProject] = []) {
        id = UUID()
        self.name = name
        createdAt = .now
        self.sortOrder = sortOrder
        self.projects = projects
    }
}

