import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case japanese = "ja"
    case english = "en"

    var id: Self { self }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}
