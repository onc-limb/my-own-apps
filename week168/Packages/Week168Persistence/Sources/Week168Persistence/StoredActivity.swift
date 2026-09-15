import Foundation
import SwiftData
import Week168Domain

@Model
final class StoredActivity {
    var id: UUID = UUID()
    var name: String = ""
    var parentID: UUID? = nil
    var sortOrder: Int = 0
    var budgetMode: String = "unset"
    var defaultPlannedMinutes: Int? = nil
    var colorHex: String = ""
    var isArchived: Bool = false

    init(_ value: Activity) {
        update(value)
    }

    func update(_ value: Activity) {
        id = value.id.rawValue
        name = value.name
        parentID = value.parentID?.rawValue
        sortOrder = value.sortOrder
        budgetMode = Self.encode(value.budgetMode)
        defaultPlannedMinutes = value.defaultPlannedMinutes
        colorHex = value.colorHex
        isArchived = value.isArchived
    }

    func domainValue() throws -> Activity {
        Activity(
            id: ActivityID(rawValue: id),
            name: name,
            parentID: parentID.map { ActivityID(rawValue: $0) },
            sortOrder: sortOrder,
            budgetMode: try decodedMode(),
            defaultPlannedMinutes: defaultPlannedMinutes,
            colorHex: colorHex,
            isArchived: isArchived
        )
    }

    private static func encode(_ mode: BudgetMode) -> String {
        switch mode {
        case .managed: "managed"
        case .unset: "unset"
        case .excluded: "excluded"
        }
    }

    private func decodedMode() throws -> BudgetMode {
        switch budgetMode {
        case "managed": .managed
        case "unset": .unset
        case "excluded": .excluded
        default: throw PersistenceError.invalidStoredValue(budgetMode)
        }
    }
}
