import SwiftUI

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.japanese.rawValue

    var body: some View {
        Form {
            Section("言語") {
                Picker("表示言語", selection: $languageCode) {
                    Text("日本語").tag(AppLanguage.japanese.rawValue)
                    Text("英語").tag(AppLanguage.english.rawValue)
                }
            }
        }
        .navigationTitle("設定")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(\.locale, AppLanguage.japanese.locale)
}
