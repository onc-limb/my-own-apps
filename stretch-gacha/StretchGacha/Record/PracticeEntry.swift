import Foundation

/// メモリ上の値型スナップショット。@Model インスタンスを保持しないことで
/// ModelContext の寿命に引きずられず、純粋関数群のテストが永続化層なしで完結する。
struct PracticeEntry: Equatable {
    let itemID: String
    let completedAt: Date
    let dayNumber: Int
}
