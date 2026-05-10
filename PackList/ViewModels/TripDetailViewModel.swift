import Foundation
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "TripDetailViewModel")

@Observable
final class TripDetailViewModel {

    let trip: TripSession
    private(set) var items: [TripItem] = []
    private(set) var isLoading = false
    private var repo: (any TripItemRepository)?

    init(trip: TripSession) {
        self.trip = trip
    }

    // MARK: - Load

    func load(repository: any TripItemRepository) async {
        repo = repository
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await repository.fetchAll(for: trip.id)
        } catch {
            logger.error("Load failed: \(error)")
        }
    }

    // MARK: - Toggle

    func toggle(item: TripItem) {
        item.completedAt = item.completedAt == nil ? Date() : nil
    }

    func save(item: TripItem) async {
        do {
            try await repo?.update(item)
        } catch {
            logger.error("Save failed: \(error)")
            item.completedAt = item.completedAt == nil ? Date() : nil
        }
    }

    // MARK: - Packing

    var packingGroups: [(location: PackingLocation, items: [TripItem])] {
        let physical = items.filter { $0.itemType == .physical }
        return Dictionary(grouping: physical, by: \.packingLocation)
            .map { location, rows in
                let incomplete = rows.filter { $0.completedAt == nil }.sorted { $0.name < $1.name }
                let complete   = rows.filter { $0.completedAt != nil }.sorted { $0.name < $1.name }
                return (location: location, items: incomplete + complete)
            }
            .sorted { $0.location.sortOrder < $1.location.sortOrder }
    }

    var categoryGroups: [(category: ItemCategory, items: [TripItem])] {
        let physical = items.filter { $0.itemType == .physical }
        return Dictionary(grouping: physical, by: \.category)
            .map { category, rows in
                let incomplete = rows.filter { $0.completedAt == nil }.sorted { $0.name < $1.name }
                let complete   = rows.filter { $0.completedAt != nil }.sorted { $0.name < $1.name }
                return (category: category, items: incomplete + complete)
            }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    var flightAccessibleItems: [TripItem] {
        items.filter { $0.itemType == .physical && $0.flightAccessible }
            .sorted { $0.name < $1.name }
    }

    var completedPacking: Int { items.filter { $0.itemType == .physical && $0.completedAt != nil }.count }
    var totalPacking:     Int { items.filter { $0.itemType == .physical }.count }

    // MARK: - Prep tasks

    var taskGroups: [(timing: TaskTiming, items: [TripItem])] {
        let tasks = items.filter { $0.itemType == .task }
        return Dictionary(grouping: tasks) { $0.recommendedTiming ?? .weekBefore }
            .map { timing, rows in
                let incomplete = rows.filter { $0.completedAt == nil }.sorted { $0.name < $1.name }
                let complete   = rows.filter { $0.completedAt != nil }.sorted { $0.name < $1.name }
                return (timing: timing, items: incomplete + complete)
            }
            .sorted { $0.timing.sortOrdinal < $1.timing.sortOrdinal }
    }

    var completedTasks: Int { items.filter { $0.itemType == .task && $0.completedAt != nil }.count }
    var totalTasks:     Int { items.filter { $0.itemType == .task }.count }

    func deadline(for timing: TaskTiming) -> Date {
        let cal = Calendar.current
        let dep = trip.departureDate
        switch timing {
        case .weekBefore:      return cal.date(byAdding: .day, value: -7, to: dep) ?? dep
        case .threeDaysBefore: return cal.date(byAdding: .day, value: -3, to: dep) ?? dep
        case .dayBefore:       return cal.date(byAdding: .day, value: -1, to: dep) ?? dep
        case .morningOf:       return dep
        case .atAirport:       return dep
        case .onPlane:         return dep
        case .uponArrival:     return dep
        }
    }
}
