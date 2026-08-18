import SwiftUI
import Combine

/// タイマー画面。ガチャ画面から fullScreenCover で提示するモーダル
/// （タブ・ナビゲーション階層を増やさず、L1 の 3 画面制約を守る）。
struct StretchTimerView: View {
    let item: StretchItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PracticeStore.self) private var practiceStore

    @State private var viewModel: StretchTimerViewModel?
    @State private var tickCancellable: AnyCancellable?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if let viewModel {
                content(viewModel)
            }
        }
        .onAppear { setUpIfNeeded() }
        .onDisappear {
            stopTicking()
            viewModel?.onDisappear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard let viewModel else { return }
            if newPhase == .active {
                viewModel.resume()
            } else {
                viewModel.pause()
            }
            syncTicking(viewModel)
        }
    }

    private func setUpIfNeeded() {
        guard viewModel == nil else { return }
        let vm = StretchTimerViewModel(item: item,
                                       recorder: StorePracticeRecorder(store: practiceStore))
        viewModel = vm
        syncTicking(vm)
    }

    private func content(_ viewModel: StretchTimerViewModel) -> some View {
        VStack(spacing: 0) {
            if viewModel.phase == .finished {
                finishedHeader
            } else {
                countdownHeader(viewModel)
            }
            StretchCardView(item: item, style: .detail)
            footer(viewModel)
                .padding(.horizontal, CardMetrics.padding)
                .padding(.bottom, TimerMetrics.screenPadding)
        }
        .padding(.top, TimerMetrics.screenPadding)
        .onChange(of: viewModel.phase) { _, _ in
            syncTicking(viewModel)
        }
    }

    private func countdownHeader(_ viewModel: StretchTimerViewModel) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(viewModel.displaySeconds)")
                    .font(.system(size: TimerMetrics.countdownFontSize, weight: .bold))
                    .monospacedDigit()
                Text(verbatim: "秒")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: TimerMetrics.progressBarHeight / 2)
                        .fill(Color(.tertiarySystemFill))
                    RoundedRectangle(cornerRadius: TimerMetrics.progressBarHeight / 2)
                        .fill(RarityStyle.accent(for: item.rarity))
                        .frame(width: geometry.size.width * viewModel.progress)
                }
            }
            .frame(height: TimerMetrics.progressBarHeight)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, CardMetrics.padding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "残り時間"))
        .accessibilityValue(Text(verbatim: "\(accessibilitySeconds(viewModel.displaySeconds))秒"))
    }

    /// VoiceOver の読み上げは 10 秒刻みに間引く（1 秒ごとの割り込みを避ける）
    private func accessibilitySeconds(_ seconds: Int) -> Int {
        (seconds / TimerMetrics.accessibilityValueStep) * TimerMetrics.accessibilityValueStep
    }

    private var finishedHeader: some View {
        Text(verbatim: "✅ 完了！")
            .font(.system(size: 32, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .accessibilityLabel(Text(verbatim: "完了"))
    }

    @ViewBuilder
    private func footer(_ viewModel: StretchTimerViewModel) -> some View {
        if viewModel.phase == .finished {
            Button {
                dismiss()
            } label: {
                Text(verbatim: "閉じる")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: TimerMetrics.footerHeight)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                viewModel.abort()
                dismiss()
            } label: {
                Text(verbatim: "やめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: TimerMetrics.footerHeight)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - ティック（paused / finished の間は publisher を止める）

    private func syncTicking(_ viewModel: StretchTimerViewModel) {
        if viewModel.phase == .running {
            startTicking(viewModel)
        } else {
            stopTicking()
        }
    }

    private func startTicking(_ viewModel: StretchTimerViewModel) {
        guard tickCancellable == nil else { return }
        tickCancellable = Timer.publish(every: TimerMetrics.tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in viewModel.tick() }
    }

    private func stopTicking() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }
}
