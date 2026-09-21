import Foundation

enum DrawEngine {
    static func draw(
        from catalog: [Stretch] = StretchCatalog.all,
        at date: Date = .now,
        streak: Int,
        profile: StretchProfile = .general,
        excluding excludedID: String? = nil,
        rarityRoll: Double = Double.random(in: 0..<1),
        candidateRoll: Double = Double.random(in: 0..<1),
        calendar: Calendar = .current
    ) -> Stretch {
        let slot = TimeSlot.current(at: date, calendar: calendar)
        var eligible = catalog.filter { stretch in
            stretch.unlockStreak <= streak
                && stretch.id != excludedID
                && (stretch.profile == .general || profile == .climber)
                && (stretch.timeSlot == .any || stretch.timeSlot == slot)
        }

        if eligible.isEmpty {
            eligible = catalog.filter {
                $0.unlockStreak <= streak
                    && $0.id != excludedID
                    && ($0.profile == .general || profile == .climber)
            }
        }

        precondition(!eligible.isEmpty, "Stretch catalog must contain an eligible item")

        let requestedRarity: StretchRarity
        switch rarityRoll {
        case ..<0.72: requestedRarity = .common
        case ..<0.96: requestedRarity = .rare
        default: requestedRarity = .ssr
        }

        let rarityCandidates = eligible.filter { $0.rarity == requestedRarity }
        let candidates = rarityCandidates.isEmpty ? eligible : rarityCandidates
        let clampedRoll = min(max(candidateRoll, 0), 0.999_999)
        let index = Int(clampedRoll * Double(candidates.count))
        return candidates[index]
    }
}
