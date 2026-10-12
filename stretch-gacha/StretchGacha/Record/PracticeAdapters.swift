import Foundation

/// OwnershipProviding（Gacha/）と PracticeRecording（Timer/）はアクター隔離のない宣言で
/// 確定済みのため、@MainActor の PracticeStore を直接準拠させると隔離の不一致になる。
/// プロトコル宣言側を変更せず、このアダプタ 2 つで吸収する。
/// 呼び出し元はいずれも @MainActor のビューモデル（GachaViewModel.spin() /
/// StretchTimerViewModel.tick()）なので、assumeIsolated の前提は構造的に満たされる。

struct StoreOwnershipProvider: OwnershipProviding {
    let store: PracticeStore

    func ownedItemIDs() -> Set<String> {
        MainActor.assumeIsolated { store.ownedItemIDs() }
    }
}

struct StorePracticeRecorder: PracticeRecording {
    let store: PracticeStore

    func recordCompletion(itemID: String, completedAt: Date) {
        MainActor.assumeIsolated { store.record(itemID: itemID, completedAt: completedAt) }
    }
}
