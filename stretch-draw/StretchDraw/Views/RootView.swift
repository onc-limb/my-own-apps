import SwiftData
import SwiftUI

struct RootView: View {
    private enum Stage: Equatable {
        case drawing
        case ready
        case active
        case completed
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyDraw.drawnAt, order: .reverse) private var records: [DailyDraw]
    @State private var todayDraw: DailyDraw?
    @State private var stage: Stage = .drawing
    @State private var remainingSeconds = 60
    @State private var timerEndsAt: Date?
    @State private var drawRotation = 0.0
    @State private var errorMessage: String?
    @State private var showingPrivacy = false

    private var stretch: Stretch? {
        todayDraw.flatMap { StretchCatalog.stretch(id: $0.stretchID) }
    }

    private var streak: Int {
        StreakService.currentStreak(records: records)
    }

    private var unlockedCount: Int {
        StretchCatalog.all.filter {
            $0.profile == .general && $0.unlockStreak <= streak
        }.count
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                statusHeader

                Spacer(minLength: 8)

                if stage == .drawing {
                    drawingView
                } else if let stretch {
                    StretchCard(
                        stretch: stretch,
                        remainingSeconds: remainingSeconds,
                        isActive: stage == .active
                    )

                    actionArea(for: stretch)
                }

                Spacer(minLength: 8)

                Text("痛みが出たら、無理をせず中止してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear(perform: loadToday)
        .task(id: stage) {
            guard stage == .active, let timerEndsAt else { return }
            while remainingSeconds > 0 && !Task.isCancelled {
                remainingSeconds = max(0, Int(ceil(timerEndsAt.timeIntervalSinceNow)))
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            if remainingSeconds == 0 {
                completeToday()
            }
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicyView()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.97, blue: 0.90), Color(red: 0.91, green: 0.98, blue: 0.94)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var statusHeader: some View {
        HStack {
            Label("\(streak)日連続", systemImage: "flame.fill")
                .foregroundStyle(.orange)

            Spacer()

            Label("\(unlockedCount)種解放", systemImage: "sparkles")
                .foregroundStyle(.secondary)

            Button("プライバシー", systemImage: "info.circle") {
                showingPrivacy = true
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.semibold))
        .accessibilityElement(children: .combine)
    }

    private var drawingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "capsule.portrait.fill")
                .font(.system(size: 112))
                .foregroundStyle(.mint, .pink)
                .rotationEffect(.degrees(drawRotation))
                .scaleEffect(drawRotation == 0 ? 0.85 : 1.0)
                .accessibilityHidden(true)

            Text("今日の1種を抽選中")
                .font(.title2.bold())
        }
    }

    @ViewBuilder
    private func actionArea(for stretch: Stretch) -> some View {
        switch stage {
        case .drawing:
            EmptyView()
        case .ready:
            if stretch.isRest {
                Button("今日は休む") {
                    completeToday()
                }
                .buttonStyle(PrimaryActionButtonStyle())
            } else {
                Button("60秒だけやる") {
                    remainingSeconds = 60
                    timerEndsAt = Date().addingTimeInterval(60)
                    stage = .active
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }

            if todayDraw?.canReroll == true {
                Button("今日はこれじゃない（あと1回）") {
                    reroll()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        case .active:
            Button("できた") {
                completeToday()
            }
            .buttonStyle(PrimaryActionButtonStyle())
        case .completed:
            VStack(spacing: 10) {
                Image(systemName: stretch.isRest ? "moon.zzz.fill" : "checkmark.seal.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(stretch.isRest ? .indigo : .green)
                Text(stretch.isRest ? "休むことまで完了" : "今日のストレッチ完了")
                    .font(.title3.bold())
                Text("また明日、1種だけ。")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func loadToday() {
        if let existing = records.first(where: { Calendar.current.isDateInToday($0.drawnAt) }) {
            todayDraw = existing
            stage = existing.completed ? .completed : .ready
            return
        }

        let selected = DrawEngine.draw(streak: streak)
        let draw = DailyDraw(stretch: selected)
        modelContext.insert(draw)
        todayDraw = draw
        persist()

        withAnimation(.spring(duration: 1.1, bounce: 0.45)) {
            drawRotation = 720
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard stage == .drawing else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                stage = .ready
            }
        }
    }

    private func reroll() {
        guard let todayDraw, todayDraw.canReroll else { return }
        let replacement = DrawEngine.draw(
            streak: streak,
            excluding: todayDraw.stretchID
        )
        todayDraw.replace(with: replacement)
        remainingSeconds = 60
        timerEndsAt = nil
        persist()
    }

    private func completeToday() {
        guard let todayDraw, !todayDraw.completed else {
            stage = .completed
            return
        }
        // ASSUMPTION: SSRの休息券を受け取ることも、その日の「やった」として連続日数に数える。
        todayDraw.complete()
        persist()
        withAnimation(.spring(duration: 0.45)) {
            stage = .completed
        }
    }

    private func persist() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(Color(red: 0.25, green: 0.45, blue: 0.40), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

#Preview {
    RootView()
        .modelContainer(for: DailyDraw.self, inMemory: true)
}
