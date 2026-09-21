import Foundation

enum StretchRarity: String, Codable, CaseIterable {
    case common
    case rare
    case ssr

    var label: String {
        switch self {
        case .common: "COMMON"
        case .rare: "RARE"
        case .ssr: "SSR"
        }
    }
}

enum TimeSlot: String, Codable {
    case any
    case morning
    case daytime
    case evening

    static func current(at date: Date, calendar: Calendar = .current) -> TimeSlot {
        switch calendar.component(.hour, from: date) {
        case 5..<11: .morning
        case 19...23, 0..<5: .evening
        default: .daytime
        }
    }
}

enum StretchProfile: String, Codable {
    case general
    case climber
}

struct Stretch: Identifiable, Equatable {
    let id: String
    let name: String
    let instruction: String
    let symbol: String
    let rarity: StretchRarity
    let timeSlot: TimeSlot
    let unlockStreak: Int
    let profile: StretchProfile
    let isRest: Bool

    init(
        id: String,
        name: String,
        instruction: String,
        symbol: String,
        rarity: StretchRarity,
        timeSlot: TimeSlot = .any,
        unlockStreak: Int = 0,
        profile: StretchProfile = .general,
        isRest: Bool = false
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.symbol = symbol
        self.rarity = rarity
        self.timeSlot = timeSlot
        self.unlockStreak = unlockStreak
        self.profile = profile
        self.isRest = isRest
    }
}
