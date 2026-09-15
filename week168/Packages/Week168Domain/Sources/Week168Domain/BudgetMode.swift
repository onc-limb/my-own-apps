public enum BudgetMode: Sendable, Equatable {
    /// 予算あり。枠を持ち、判定される。
    case managed(BudgetDirection)
    /// 予算未設定。親の残り枠を共有する。
    case unset
    /// 予算対象外。いかなる枠も消費しない。
    case excluded
}
