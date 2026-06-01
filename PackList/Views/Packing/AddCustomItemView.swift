import SwiftUI

struct AddCustomItemView: View {
    let onAdd: (String, ItemCategory, PackingLocation, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: ItemCategory = .misc
    @State private var location: PackingLocation = .carryOn
    @State private var quantity = 1

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                        .accessibilityIdentifier("customItemNameField")
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    Picker("Location", selection: $location) {
                        ForEach(PackingLocation.allCases, id: \.self) { loc in
                            Text(loc.displayName).tag(loc)
                        }
                    }
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }
            }
            .navigationTitle("Add Item")
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
                        onAdd(trimmed, category, location, quantity)
                        dismiss()
                    }
                    .disabled(!canAdd)
                    .accessibilityIdentifier("confirmAddItemButton")
                }
            }
        }
    }
}
