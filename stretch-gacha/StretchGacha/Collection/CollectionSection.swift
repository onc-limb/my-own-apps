import Foundation

struct CollectionSection: Equatable, Identifiable {
    let id: String              // BodyPart.rawValue
    let title: String           // BodyPart.displayName
    let cells: [CollectionCellContent]
}
