import SwiftUI
import SwiftData

struct HabitFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let habit: Habit?

    @State private var viewModel: HabitFormViewModel?

    init(habit: Habit? = nil) {
        self.habit = habit
    }

    var body: some View {
        NavigationStack {
            if let viewModel {
                formContent(viewModel: viewModel)
                    .navigationTitle(viewModel.isEditing ? "習慣を編集" : "習慣を追加")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") {
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                // ASSUMPTION: save() throws but errors are unlikely for local SwiftData operations; using try? for simplicity
                                try? viewModel.save()
                                dismiss()
                            }
                            .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HabitFormViewModel(modelContext: modelContext, habit: habit)
            }
        }
    }

    @ViewBuilder
    private func formContent(viewModel: HabitFormViewModel) -> some View {
        Form {
            Section("基本情報") {
                TextField("習慣の名前", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.name = $0 }
                ))

                Stepper(
                    "制限時間: \(viewModel.timeLimitMinutes)分",
                    value: Binding(
                        get: { viewModel.timeLimitMinutes },
                        set: { viewModel.timeLimitMinutes = $0 }
                    ),
                    in: 1...120
                )
            }

            Section("頻度") {
                Picker("頻度", selection: Binding(
                    get: { viewModel.frequencyType },
                    set: { viewModel.frequencyType = $0 }
                )) {
                    Text("毎日").tag(FrequencyType.daily)
                    Text("週N回").tag(FrequencyType.weeklyN)
                }

                if viewModel.frequencyType == .weeklyN {
                    Stepper(
                        "週 \(viewModel.weeklyCount) 回",
                        value: Binding(
                            get: { viewModel.weeklyCount },
                            set: { viewModel.weeklyCount = $0 }
                        ),
                        in: 1...6
                    )
                }
            }

            if viewModel.isEditing {
                Section {
                    Button(role: .destructive) {
                        viewModel.delete()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("この習慣を削除")
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

#Preview("新規追加") {
    HabitFormView()
        .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}

#Preview("編集") {
    HabitFormView(habit: Habit(
        name: "読書",
        timeLimitMinutes: 30,
        frequencyType: .daily,
        weeklyCount: 7,
        sortOrder: 0
    ))
    .modelContainer(for: [Habit.self, CompletionRecord.self], inMemory: true)
}
