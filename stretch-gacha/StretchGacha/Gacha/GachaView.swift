import SwiftUI
import SwiftData

/// ガチャ画面（ルートタブの既定画面）。待機・演出・結果の 3 状態を描画する。
/// 演出は scale / rotation / opacity / 色補間のみ（60fps 維持のため blur / shadow は使わない）。
struct GachaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PracticeStore.self) private var practiceStore

    @State private var viewModel: GachaViewModel?
    @State private var dailyStore: DailyDrawStore?
    @State private var timerItem: StretchItem?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            content
        }
        .onAppear { setUpIfNeeded() }
        .fullScreenCover(item: $timerItem) { item in
            StretchTimerView(item: item)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.phase {
            case .idle:
                idleView(viewModel)
            case .performing(let outcome):
                performingView(viewModel, outcome: outcome)
            case .revealed(let item):
                revealedView(viewModel, item: item)
            }
        } else {
            Color.clear
        }
    }

    private func setUpIfNeeded() {
        guard viewModel == nil else { return }
        // カタログのウォームアップ + 当日ドロー状態の fetch 1 本（タップ後の経路から I/O を排除する）
        let catalog = StretchCatalog.shared
        let store = DailyDrawStore(context: modelContext)
        _ = store.loadDrawnTodayIDs(validAgainst: catalog)
        dailyStore = store
        viewModel = GachaViewModel(catalog: catalog,
                                   ownership: StoreOwnershipProvider(store: practiceStore),
                                   store: store,
                                   reduceMotion: { reduceMotion })
    }

    // MARK: - 待機

    private func idleView(_ viewModel: GachaViewModel) -> some View {
        VStack {
            Spacer()
            capsule(tint: nil, scale: 1, rotation: .zero)
            Spacer()
            primaryButton("回す") { viewModel.spin() }
        }
        .padding(16)
    }

    // MARK: - 演出

    private func performingView(_ viewModel: GachaViewModel, outcome: GachaOutcome) -> some View {
        VStack {
            Spacer()
            CapsulePerformanceView(outcome: outcome, reduceMotion: reduceMotion)
            Spacer()
            primaryButton("回す") {}
                .disabled(true)
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.skip() }   // 画面のどこをタップしてもスキップ
        .task(id: outcome.item.id) {
            let hapticMoment = reduceMotion
                ? GachaAnimation.reducedMotionHapticMoment
                : GachaAnimation.hapticMoment
            if outcome.isHighlighted {
                try? await Task.sleep(for: .seconds(hapticMoment))
                guard !Task.isCancelled else { return }
                viewModel.hapticMomentReached()
                try? await Task.sleep(for: .seconds(outcome.duration - hapticMoment))
            } else {
                try? await Task.sleep(for: .seconds(outcome.duration))
            }
            guard !Task.isCancelled else { return }
            viewModel.finishPerformance()
        }
    }

    private func capsule(tint: Color?, scale: CGFloat, rotation: Angle) -> some View {
        ZStack {
            Circle()
                .fill(tint ?? Color(.secondarySystemBackground))
                .frame(width: 160, height: 160)
            Text(verbatim: "🎁")
                .font(.system(size: 72))
        }
        .scaleEffect(scale)
        .rotationEffect(rotation)
        .accessibilityHidden(true)
    }

    // MARK: - 結果

    private func revealedView(_ viewModel: GachaViewModel, item: StretchItem) -> some View {
        StretchCardView(item: item, style: .result) {
            HStack(spacing: 12) {
                Button {
                    timerItem = item
                } label: {
                    Text(verbatim: "はじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.spin()
                } label: {
                    Text(verbatim: "もう1回")
                        .font(.headline)
                        .frame(width: 116, height: 56)
                }
                .buttonStyle(.bordered)
            }
        }
        .transition(.opacity)
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
    }
}

/// 演出中のカプセル。アニメーション対象は scale / rotation / opacity / 色補間に限定する。
private struct CapsulePerformanceView: View {
    let outcome: GachaOutcome
    let reduceMotion: Bool

    @State private var animating = false

    var body: some View {
        let tint = outcome.isHighlighted
            ? RarityStyle.accent(for: outcome.item.rarity).opacity(0.35)
            : Color(.secondarySystemBackground)
        ZStack {
            Circle()
                .fill(animating ? tint : Color(.secondarySystemBackground))
                .frame(width: 160, height: 160)
            Text(verbatim: "🎁")
                .font(.system(size: 72))
        }
        .scaleEffect(animating && !reduceMotion ? 1.25 : 1)
        .rotationEffect(reduceMotion ? .zero : .degrees(animating ? 360 : 0))
        .opacity(animating ? 0.9 : 1)
        .animation(.easeInOut(duration: outcome.duration), value: animating)
        .onAppear { animating = true }
        .accessibilityHidden(true)
    }
}
