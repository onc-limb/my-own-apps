import Foundation

/// 確認済みバージョンの読み書き。UserDefaults に Int 1 個だけを保存する
/// （SwiftData モデルを足すと起動経路に fetch が増えるため使わない）。
/// integer(forKey:) は未保存・型違いで 0 を返す ＝「表示する」側へ倒れる。
/// synchronize() は呼ばない（iOS 12 以降は不要。タップ直後の強制終了で flush されなくても
/// 1 回余分に表示されるだけで、回復処理は設けない）。
struct SafetyNoticeStore {
    static let acceptedVersionKey = "safetyNotice.acceptedVersion"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var acceptedVersion: Int {
        defaults.integer(forKey: Self.acceptedVersionKey)
    }

    func accept(version: Int = SafetyNoticeGate.currentVersion) {
        defaults.set(version, forKey: Self.acceptedVersionKey)
    }
}
