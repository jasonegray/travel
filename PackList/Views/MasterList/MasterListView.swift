import SwiftUI

struct MasterListView: View {
    @State private var vm = MasterListViewModel()
    @Environment(\.repositories) private var repositories

    var body: some View {
        List {
            // Filter row
            Section {
                Picker("Type", selection: $vm.typeFilter) {
                    ForEach(MasterItemTypeFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)

            if vm.filteredGroupedItems.isEmpty && !vm.isLoading {
                emptyState
            } else {
                ForEach(vm.filteredGroupedItems, id: \.category) { group in
                    Section(group.category.displayName) {
                        ForEach(group.items) { item in
                            MasterItemRow(
                                item: item,
                                onTap: { vm.selectedItem = item },
                                onToggle: { vm.toggleActive(item: item) }
                            )
                            .opacity(item.isActive ? 1.0 : 0.45)
                        }
                    }
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Search items")
        .navigationTitle("Master List")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    vm.showAddItemSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $vm.selectedItem) { item in
            MasterItemDetailSheet(item: item, onToggle: {
                vm.toggleActive(item: item)
            })
        }
        .sheet(isPresented: $vm.showAddItemSheet) {
            AddMasterItemView { name, category, itemType, packingLocation, tags, isAlwaysInclude, defaultQuantity in
                Task {
                    guard let repos = repositories else { return }
                    await vm.addItem(
                        name: name,
                        category: category,
                        itemType: itemType,
                        packingLocation: packingLocation,
                        tags: tags,
                        isAlwaysInclude: isAlwaysInclude,
                        defaultQuantity: defaultQuantity,
                        repository: repos.masterItems
                    )
                }
            }
        }
        .task {
            guard let repos = repositories else { return }
            await vm.load(repository: repos.masterItems)
        }
    }

    private var emptyState: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(vm.searchText.isEmpty ? "No items" : "No results for \"\(vm.searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 32)
                Spacer()
            }
        }
        .listRowSeparator(.hidden)
    }
}

// MARK: - Item row

private struct MasterItemRow: View {
    let item: MasterItem
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let location = item.packingLocation {
                        LocationBadge(location: location)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Toggle("Active", isOn: Binding(
                get: { item.isActive },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Location badge

private struct LocationBadge: View {
    let location: PackingLocation

    var body: some View {
        Text(location.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Item detail sheet

private struct MasterItemDetailSheet: View {
    let item: MasterItem
    let onToggle: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Category", value: item.category.displayName)
                }

                Section("Packing") {
                    if let location = item.packingLocation {
                        LabeledContent("Location", value: location.displayName)
                    }
                    LabeledContent("Default Qty", value: "\(item.defaultQuantity)")
                }

                Section {
                    Toggle("Active", isOn: Binding(
                        get: { item.isActive },
                        set: { _ in onToggle() }
                    ))
                } footer: {
                    Text("Inactive items are excluded from new trip generation.")
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
    }
}

