import Foundation

enum StretchCatalog {
    static let all: [Stretch] = [
        Stretch(
            id: "neck-reset",
            name: "首すじリセット",
            instruction: "肩を下げたまま、頭を左右へゆっくり倒す。反動はつけない。",
            symbol: "figure.mind.and.body",
            rarity: .common,
            timeSlot: .morning
        ),
        Stretch(
            id: "shoulder-circles",
            name: "肩まわし",
            instruction: "指先を肩に置き、肘で大きな円を描く。前後を入れ替えて続ける。",
            symbol: "arrow.trianglehead.2.clockwise.rotate.90",
            rarity: .common
        ),
        Stretch(
            id: "chest-opener",
            name: "胸ひらき",
            instruction: "背中で手を組み、胸を持ち上げる。腰は反らしすぎない。",
            symbol: "figure.arms.open",
            rarity: .common,
            timeSlot: .morning
        ),
        Stretch(
            id: "seated-twist",
            name: "座ってひねる",
            instruction: "背筋を伸ばして座り、息を吐きながら上半身を左右へひねる。",
            symbol: "figure.cooldown",
            rarity: .common,
            timeSlot: .evening
        ),
        Stretch(
            id: "hip-flexor",
            name: "股関節の前を伸ばす",
            instruction: "片膝立ちになり、骨盤を正面へ向けたまま体重を前へ移す。",
            symbol: "figure.flexibility",
            rarity: .rare,
            unlockStreak: 3
        ),
        Stretch(
            id: "deep-squat",
            name: "深いスクワットで休む",
            instruction: "足裏を床につけて腰を落とし、肘で膝を軽く外へ押す。",
            symbol: "figure.strengthtraining.traditional",
            rarity: .rare,
            timeSlot: .evening,
            unlockStreak: 3
        ),
        Stretch(
            id: "thoracic-rotation",
            name: "胸椎オープンブック",
            instruction: "横向きで膝を重ね、上の腕を反対側へ開く。視線も手を追う。",
            symbol: "figure.pilates",
            rarity: .rare,
            timeSlot: .evening,
            unlockStreak: 7
        ),
        Stretch(
            id: "rest-ticket",
            name: "今日は休んでいい券",
            instruction: "回復もトレーニングの一部。深呼吸をひとつして、今日は終了。",
            symbol: "bed.double.fill",
            rarity: .ssr,
            isRest: true
        ),
        Stretch(
            id: "climber-forearm",
            name: "前腕リリース",
            instruction: "腕を前へ伸ばし、反対の手で指先を手前へ引く。左右を入れ替える。",
            symbol: "hand.raised.fill",
            rarity: .common,
            profile: .climber
        ),
        Stretch(
            id: "climber-scapula",
            name: "肩甲骨スライド",
            instruction: "壁に前腕を当て、肩をすくめず腕を上下へ滑らせる。",
            symbol: "figure.climbing",
            rarity: .rare,
            unlockStreak: 3,
            profile: .climber
        ),
        Stretch(
            id: "climber-frog",
            name: "フロッグストレッチ",
            instruction: "四つ這いから膝を開き、背中を丸めず腰をゆっくり後ろへ引く。",
            symbol: "figure.climbing",
            rarity: .rare,
            timeSlot: .evening,
            unlockStreak: 7,
            profile: .climber
        )
    ]

    static func stretch(id: String) -> Stretch? {
        all.first { $0.id == id }
    }
}
