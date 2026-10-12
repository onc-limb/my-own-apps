import Foundation
import Observation

enum GachaPhase: Equatable {
    case idle
    case performing(GachaOutcome)
    case revealed(StretchItem)
}

struct GachaOutcome: Equatable {
    let item: StretchItem
    let isHighlighted: Bool   // rarity == .sr || .ur
    let duration: Double      // 1.2 / 1.8 / 0.3(Reduce Motion)
}

/// ガチャ画面の状態機械。抽選は演出の前に確定させる（演出がレア度に依存するため）。
/// 時間経過はビュー側の task が駆動し、テストはメソッド直接呼び出しで状態遷移を検証する。
@Observable
@MainActor
final class GachaViewModel {
    private(set) var phase: GachaPhase = .idle

    private let catalog: StretchCatalog
    private let ownership: OwnershipProviding
    private let store: DailyDrawStore
    private let makeRNG: () -> any RandomNumberGenerator
    private let fireHaptic: @MainActor () -> Void
    private var hapticFiredForCurrentSpin = false
    private var revealedHandledForCurrentSpin = false

    init(catalog: StretchCatalog = .shared,
         ownership: OwnershipProviding,
         store: DailyDrawStore,
         makeRNG: @escaping () -> any RandomNumberGenerator = { SystemRandomNumberGenerator() },
         fireHaptic: @escaping @MainActor () -> Void = HapticPlayer.impactMedium,
         reduceMotion: @escaping () -> Bool = { false }) {
        self.catalog = catalog
        self.ownership = ownership
        self.store = store
        self.makeRNG = makeRNG
        self.fireHaptic = fireHaptic
        self.reduceMotion = reduceMotion
    }

    private let reduceMotion: () -> Bool

    /// idle / revealed のときのみ有効。performing 中は無視（連打による二重抽選防止）。
    func spin() {
        switch phase {
        case .performing: return
        case .idle, .revealed: break
        }
        var rng = makeRNG()
        let context = DrawContext(catalog: catalog,
                                  ownedItemIDs: ownership.ownedItemIDs(),
                                  drawnTodayItemIDs: store.currentDrawnTodayIDs)
        let item = GachaDrawer.draw(context, using: &rng)
        store.recordInMemory(itemID: item.id)   // メモリのみ。I/O はここでは行わない
        let highlighted = item.rarity == .sr || item.rarity == .ur
        let duration = reduceMotion()
            ? GachaAnimation.reducedMotionDuration
            : (highlighted ? GachaAnimation.highlightedDuration : GachaAnimation.normalDuration)
        hapticFiredForCurrentSpin = false
        revealedHandledForCurrentSpin = false
        phase = .performing(GachaOutcome(item: item, isHighlighted: highlighted, duration: duration))
    }

    /// performing のときのみ有効。即 revealed へ（待ち時間 0）。
    func skip() {
        guard case .performing(let outcome) = phase else { return }
        phase = .revealed(outcome.item)
        onRevealed()
    }

    /// 演出完走時にビューから呼ばれる合流点。
    func finishPerformance() {
        guard case .performing(let outcome) = phase else { return }
        phase = .revealed(outcome.item)
        onRevealed()
    }

    /// SR/UR 演出の規定タイミングでビューから呼ばれる。1 回だけ発火する。
    func hapticMomentReached() {
        guard case .performing(let outcome) = phase, outcome.isHighlighted,
              !hapticFiredForCurrentSpin else { return }
        hapticFiredForCurrentSpin = true
        fireHaptic()
    }

    /// 演出完走・スキップ双方の合流点。save はここで 1 回だけ。
    func onRevealed() {
        guard !revealedHandledForCurrentSpin else { return }
        revealedHandledForCurrentSpin = true
        store.flush()
    }
}
