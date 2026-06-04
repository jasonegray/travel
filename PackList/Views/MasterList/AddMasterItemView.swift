import SwiftUI

struct AddMasterItemView: View {
    let onAdd: (String, ItemCategory, ItemType, PackingLocation?, Set<ItemTag>, Bool, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: ItemCategory = .misc
    @State private var itemType: ItemType = .physical
    @State private var includeLocation = true
    @State private var packingLocation: PackingLocation = .carryOn
    @State private var selectedTags: Set<ItemTag> = []
    @State private var isAlwaysInclude = false
    @State private var defaultQuantity = 1

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                        .accessibilityIdentifier("masterItemNameField")
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    Picker("Type", selection: $itemType) {
                        Text("Physical").tag(ItemType.physical)
                        Text("Task").tag(ItemType.task)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Packing location", isOn: $includeLocation)
                    if includeLocation {
                        Picker("Location", selection: $packingLocation) {
                            ForEach(PackingLocation.allCases, id: \.self) { loc in
                                Text(loc.displayName).tag(loc)
                            }
                        }
                    }
                    Stepper("Default quantity: \(defaultQuantity)", value: $defaultQuantity, in: 1...99)
                }

                Section {
                    NavigationLink {
                        TagsSelectionView(selected: $selectedTags)
                    } label: {
                        LabeledContent("Tags") {
                            Text(selectedTags.isEmpty ? "None" : "\(selectedTags.count) selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Always include", isOn: $isAlwaysInclude)
                } footer: {
                    Text("Always-include items appear on every trip regardless of activities.")
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, category, itemType, includeLocation ? packingLocation : nil, selectedTags, isAlwaysInclude, defaultQuantity)
                        dismiss()
                    }
                    .disabled(!canAdd)
                    .accessibilityIdentifier("confirmAddMasterItemButton")
                }
            }
        }
    }
}

// MARK: - Tags selection

private struct TagsSelectionView: View {
    @Binding var selected: Set<ItemTag>

    var body: some View {
        List {
            ForEach(ItemTag.allCases, id: \.self) { (tag: ItemTag) in
                Button {
                    if selected.contains(tag) { selected.remove(tag) }
                    else { selected.insert(tag) }
                } label: {
                    HStack {
                        Text(tag.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected.contains(tag) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ItemTag display

private extension ItemTag {
    var displayName: String {
        switch self {
        case .always:           return "Always"
        case .golf:             return "Golf"
        case .beach:            return "Beach"
        case .pool:             return "Pool"
        case .workout:          return "Workout"
        case .business:         return "Business"
        case .formal:           return "Formal"
        case .cold:             return "Cold Weather"
        case .mild:             return "Mild Weather"
        case .warm:             return "Warm Weather"
        case .rainy:            return "Rainy"
        case .tropical:         return "Tropical"
        case .longHaul:         return "Long Haul"
        case .overnightFlight:  return "Overnight Flight"
        case .flightAccessible: return "Flight Accessible"
        case .wearOnPlane:      return "Wear on Plane"
        case .international:    return "International"
        case .domestic:         return "Domestic"
        case .japan:            return "Japan"
        case .asia:             return "Asia"
        case .europe:           return "Europe"
        case .us:               return "United States"
        case .korea:            return "Korea"
        case .canada:           return "Canada"
        case .longTrip:         return "Long Trip"
        case .shortTrip:        return "Short Trip"
        case .airbnb:           return "Airbnb"
        case .family:           return "Family"
        case .solo:             return "Solo"
        case .personal:         return "Personal"
        case .casual:           return "Casual"
        case .conference:       return "Conference"
        case .medicalAppointment: return "Medical Appointment"
        case .injury:           return "Injury"
        case .workKit:          return "Work Kit"
        case .interacPhone:     return "Interac Phone"
        case .interacLaptop:    return "Interac Laptop"
        case .level19Laptop:    return "Level 19 Laptop"
        case .situational:      return "Situational"
        case .conditional:      return "Conditional"
        }
    }
}
