import SwiftUI

struct SettingsView: View {

    // MARK: - Properties

    @AppStorage("dayStartHour") private var dayStartHour: Int = 4

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("一日の始まり", selection: $dayStartHour) {
                        ForEach(0...6, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                } footer: {
                    Text("設定した時間より前の記録は前日扱いになります")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
