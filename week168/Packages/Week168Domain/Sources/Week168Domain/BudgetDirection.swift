/// 上限は超過、目標は未達を判定する。
public enum BudgetDirection: String, Sendable, Codable {
    case cap, goal
}
