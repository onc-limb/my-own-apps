import SwiftUI

struct StretchCard: View {
    let stretch: Stretch
    let remainingSeconds: Int
    let isActive: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(stretch.rarity.label)
                .font(.caption.bold())
                .tracking(2)
                .foregroundStyle(rarityColor)

            Image(systemName: stretch.symbol)
                .font(.system(size: 74))
                .foregroundStyle(rarityColor)
                .symbolEffect(.pulse, options: .repeating, isActive: isActive)
                .accessibilityHidden(true)

            Text(stretch.name)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(stretch.instruction)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if isActive {
                Text("\(remainingSeconds)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("残り\(remainingSeconds)秒")
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(rarityColor.opacity(0.25), lineWidth: 2)
        }
        .accessibilityElement(children: .contain)
    }

    private var rarityColor: Color {
        switch stretch.rarity {
        case .common: .teal
        case .rare: .purple
        case .ssr: .orange
        }
    }
}
