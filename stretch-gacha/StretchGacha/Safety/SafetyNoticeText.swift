/// 画面に出る全文字列の単一の置き場。App Store 公開時の文言点検はこのファイルだけを見る。
/// 禁止語（治る・治療・効能・医学・監修・診断・処方）と受診勧奨・効能・強度・回数の推奨を
/// 含めない。書くのは行為の中止と加減に関する記述のみ。
enum SafetyNoticeText {
    static let emoji = "⚠️"
    static let headline = "はじめる前に"
    static let body: [String] = [
        "痛みが出たら、すぐに中止してください。",
        "反動をつけず、ゆっくり動かしてください。",
        "体調がすぐれない日は、無理をしないでください。",
    ]
    static let acceptButton = "わかりました"
}
