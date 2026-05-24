import Foundation
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "MasterListViewModel")

enum MasterItemTypeFilter: String, CaseIterable {
    case all, physical, task

    var displayName: String {
        switch self {
        case .all:      return "All"
        case .physical: return "Physical"
        case .task:     return "Tasks"
        }
    }
}

@Observable
final class MasterListViewModel {
    private(set) var items: [MasterItem] = []
    private(set) var isLoading = false
    var searchText = ""
    var typeFilter: MasterItemTypeFilter = .all
    var selectedItem: MasterItem?
    var showAddItemSheet = false

    // MARK: - Filtered / grouped

    var filteredGroupedItems: [(category: ItemCategory, items: [MasterItem])] {
        let filtered = items.filter { item in
            let matchesType: Bool = {
                switch typeFilter {
                case .all:      return true
                case .physical: return item.itemType == .physical
                case .task:     return item.itemType == .task
                }
            }()
            let matchesSearch = searchText.isEmpty
                || item.name.localizedCaseInsensitiveContains(searchText)
            return matchesType && matchesSearch
        }

        let grouped = Dictionary(grouping: filtered, by: \.category)

        return ItemCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category -> (category: ItemCategory, items: [MasterItem])? in
                guard let categoryItems = grouped[category], !categoryItems.isEmpty else { return nil }
                let sorted = categoryItems.sorted {
                    if $0.isActive != $1.isActive { return $0.isActive }
                    return $0.name < $1.name
                }
                return (category: category, items: sorted)
            }
    }

    // MARK: - Load

    func load(repository: any MasterItemRepository) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await repository.fetchAll()
        } catch {
            logger.error("MasterList load failed: \(error)")
        }
    }

    // MARK: - Toggle active

    func toggleActive(item: MasterItem) {
        item.isActive.toggle()
        item.updatedAt = Date()
    }
}
