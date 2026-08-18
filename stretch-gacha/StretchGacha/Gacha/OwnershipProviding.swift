import Foundation

/// 未入手補正のための依存ポート。実装は practice-record 側（StoreOwnershipProvider）。
protocol OwnershipProviding {
    /// 図鑑に登録済み（＝1 回以上実施完了した）種目 ID
    func ownedItemIDs() -> Set<String>
}

/// プレビュー・テスト用の既定実装。常に空集合を返し、同レア度内は均等抽選に縮退する。
struct EmptyOwnershipProvider: OwnershipProviding {
    func ownedItemIDs() -> Set<String> { [] }
}
