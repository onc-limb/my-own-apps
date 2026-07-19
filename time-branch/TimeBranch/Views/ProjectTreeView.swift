import SwiftUI

struct ProjectTreeView<RowContent: View>: View {
    let projects: [WorkProject]
    let depth: Int
    @ViewBuilder let rowContent: (WorkProject, Int) -> RowContent

    init(
        projects: [WorkProject],
        depth: Int = 0,
        @ViewBuilder rowContent: @escaping (WorkProject, Int) -> RowContent
    ) {
        self.projects = projects
        self.depth = depth
        self.rowContent = rowContent
    }

    var body: some View {
        ForEach(projects.sorted(by: projectSort)) { project in
            rowContent(project, depth)
            if !project.sortedChildren.isEmpty {
                ProjectTreeView(projects: project.sortedChildren, depth: depth + 1, rowContent: rowContent)
            }
        }
    }

    private func projectSort(_ lhs: WorkProject, _ rhs: WorkProject) -> Bool {
        if lhs.sortOrder == rhs.sortOrder { return lhs.name < rhs.name }
        return lhs.sortOrder < rhs.sortOrder
    }
}

