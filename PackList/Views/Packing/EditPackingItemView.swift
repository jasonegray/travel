import SwiftUI

struct EditPackingItemView: View {
    let item: TripItem
    let onSave: (Int, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: Int
    @State private var notes: String

    init(item: TripItem, onSave: @escaping (Int, String?) -> Void) {
        self.item = item
        self.onSave = onSave
        _quantity = State(wrappedValue: item.quantity)
        _notes = State(wrappedValue: item.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quantity") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...20)
                }
                Section {
                    TextField("Add a note…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Notes appear below the item name in your packing list.")
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
            onSave(quantity, trimmed.isEmpty ? nil : trimmed)
        }
    }
}
