/// 表示要否の純粋関数。Foundation すら不要。
/// フェイルセーフの向きは「表示する」に固定する（未保存・0・負値・型違いのすべてが
/// 単一の比較式 acceptedVersion < currentVersion で「表示する」側へ倒れる）。
enum SafetyNoticeGate {

    /// 現行の注意書きバージョン。文言を実質的に変更したときだけ +1 する
    /// （App Store 公開時の文言追加で既存ユーザーへ再提示できるよう Bool ではなく Int で持つ）。
    static let currentVersion = 1

    static func shouldPresent(acceptedVersion: Int,
                              currentVersion: Int = SafetyNoticeGate.currentVersion) -> Bool {
        acceptedVersion < currentVersion
    }
}
