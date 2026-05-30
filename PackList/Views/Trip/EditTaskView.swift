import SwiftUI

struct EditTaskView: View {
    let item: TripItem
    let onSave: (TaskTiming, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var timing: TaskTiming
    @State private var notes: String

    init(item: TripItem, onSave: @escaping (TaskTiming, String?) -> Void) {
        self.item = item
        self.onSave = onSave
        _timing = State(wrappedValue: item.recommendedTiming ?? .weekBefore)
        _notes = State(wrappedValue: item.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    Picker("Timing", selection: $timing) {
                        ForEach(TaskTiming.allCases, id: \.self) { t in
                            Text(t.sectionLabel).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    TextField("Add a note…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Notes appear below the task name in your prep list.")
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(timing, trimmed.isEmpty ? nil : trimmed)
        }
    }
}
