import SwiftUI

struct AddCustomTaskView: View {
    let onAdd: (String, TaskTiming) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var timing: TaskTiming = .weekBefore

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task name", text: $name)
                        .onSubmit {
                            let trimmed = name.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            HapticManager.rigidImpact()
                            onAdd(trimmed, timing)
                            dismiss()
                        }
                }
                Section {
                    Picker("When", selection: $timing) {
                        ForEach(TaskTiming.allCases, id: \.self) { t in
                            Text(t.sectionLabel).tag(t)
                        }
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        HapticManager.rigidImpact()
                        onAdd(trimmed, timing)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}
