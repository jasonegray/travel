import Foundation
import os.log
import UIKit

private let logger = Logger(subsystem: "com.packlist", category: "TripDetailViewModel")

@Observable
final class TripDetailViewModel {

    let trip: TripSession
    private(set) var items: [TripItem] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    var toastMessage: String?
    private var repo: (any TripItemRepository)?

    init(trip: TripSession) {
        self.trip = trip
    }

    // MARK: - Load

    func load(repository: any TripItemRepository) async {
        repo = repository
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            items = try await repository.fetchAll(for: trip.id)
        } catch {
            logger.error("Load failed: \(error)")
            loadFailed = true
        }
    }

    // MARK: - Toggle

    func toggle(item: TripItem) {
        guard !trip.isArchived else { return }
        let completing = item.completedAt == nil
        item.completedAt = completing ? Date() : nil
        UIImpactFeedbackGenerator(style: completing ? .medium : .light).impactOccurred()
    }

    func save(item: TripItem) async {
        guard !trip.isArchived else { return }
        do {
            try await repo?.update(item)
        } catch {
            logger.error("Save failed: \(error)")
            item.completedAt = item.completedAt == nil ? Date() : nil
            toastMessage = "Couldn't save — change was reversed"
        }
    }

    func markCompleted(sessions: any TripSessionRepository) async {
        trip.manuallyCompletedAt = Date()
        do {
            try await sessions.update(trip)
        } catch {
            logger.error("markCompleted failed: \(error)")
            trip.manuallyCompletedAt = nil
        }
    }

    func archiveTrip(sessions: any TripSessionRepository) async {
        trip.isArchived = true
        do {
            try await sessions.update(trip)
        } catch {
            logger.error("archiveTrip failed: \(error)")
            trip.isArchived = false
        }
    }

    func unarchiveTrip(sessions: any TripSessionRepository) async {
        trip.isArchived = false
        do {
            try await sessions.update(trip)
        } catch {
            logger.error("unarchiveTrip failed: \(error)")
            trip.isArchived = true
        }
    }

    func editItem(_ item: TripItem, quantity: Int, notes: String?) async {
        guard !trip.isArchived else { return }
        let prevQuantity = item.quantity
        let prevNotes = item.notes
        item.quantity = quantity
        item.notes = notes
        do {
            try await repo?.update(item)
        } catch {
            logger.error("editItem failed: \(error)")
            item.quantity = prevQuantity
            item.notes = prevNotes
        }
    }

    func editTask(_ item: TripItem, timing: TaskTiming, notes: String?) async {
        guard !trip.isArchived else { return }
        guard let repo else {
            logger.error("editTask: repository not loaded")
            return
        }
        let prevTiming = item.recommendedTiming
        let prevNotes = item.notes
        item.recommendedTiming = timing
        item.notes = notes
        do {
            try await repo.update(item)
        } catch {
            logger.error("editTask failed: \(error)")
            item.recommendedTiming = prevTiming
            item.notes = prevNotes
        }
    }

    func deleteTrip(sessions: any TripSessionRepository) async {
        do {
            try await sessions.delete(trip)
        } catch {
            logger.error("deleteTrip failed: \(error)")
        }
    }

    func editTrip(
        name: String,
        destination: String,
        departureDate: Date,
        returnDate: Date,
        sessions: any TripSessionRepository
    ) async {
        let prev = (
            name: trip.name,
            destination: trip.destination,
            departure: trip.departureDate,
            returnDate: trip.returnDate,
            updatedAt: trip.updatedAt
        )
        trip.name = name
        trip.destination = destination
        trip.departureDate = departureDate
        trip.returnDate = returnDate
        trip.updatedAt = Date()
        do {
            try await sessions.update(trip)
        } catch {
            logger.error("editTrip failed: \(error)")
            trip.name = prev.name
            trip.destination = prev.destination
            trip.departureDate = prev.departure
            trip.returnDate = prev.returnDate
            trip.updatedAt = prev.updatedAt
        }
    }

    // MARK: - Packing

    var packingGroups: [(location: PackingLocation, items: [TripItem])] {
        let physical = items.filter { $0.itemType == .physical }
        return Dictionary(grouping: physical, by: \.packingLocation)
            .map { location, rows in
                let incomplete = rows.filter { $0.completedAt == nil }.sorted {
                    if ($0.source == .manual) != ($1.source == .manual) { return $0.source == .manual }
                    return $0.name < $1.name
                }
                let complete = rows.filter { $0.completedAt != nil }.sorted { $0.name < $1.name }
                return (location: location, items: incomplete + complete)
            }
            .sorted { $0.location.sortOrder < $1.location.sortOrder }
    }

    var categoryGroups: [(category: ItemCategory, items: [TripItem])] {
        let physical = items.filter { $0.itemType == .physical }
        return Dictionary(grouping: physical, by: \.category)
            .map { category, rows in
                let incomplete = rows.filter { $0.completedAt == nil }.sorted {
                    if ($0.source == .manual) != ($1.source == .manual) { return $0.source == .manual }
                    return $0.name < $1.name
                }
                let complete = rows.filter { $0.completedAt != nil }.sorted { $0.name < $1.name }
                return (category: category, items: incomplete + complete)
            }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    // MARK: - Custom items

    func addCustomItem(name: String, category: ItemCategory, location: PackingLocation, quantity: Int) async {
        guard let repo else {
            logger.error("addCustomItem: repository not loaded")
            return
        }
        let item = TripItem(
            tripId: trip.id,
            name: name,
            category: category,
            quantity: quantity,
            packingLocation: location,
            flightAccessible: false,
            source: .manual
        )
        items.append(item)
        do {
            try await repo.insert(item)
        } catch {
            logger.error("addCustomItem failed: \(error)")
            items.removeAll { $0.id == item.id }
        }
    }

    func addCustomTask(name: String, timing: TaskTiming) async {
        guard !trip.isArchived else { return }
        guard let repo else {
            logger.error("addCustomTask: repository not loaded")
            return
        }
        let item = TripItem(
            tripId: trip.id,
            name: name,
            category: .misc,
            itemType: .task,
            quantity: 1,
            packingLocation: .carryOn,
            flightAccessible: false,
            recommendedTiming: timing,
            source: .manual
        )
        items.append(item)
        do {
            try await repo.insert(item)
        } catch {
            logger.error("addCustomTask failed: \(error)")
            items.removeAll { $0.id == item.id }
        }
    }

    func setItems(_ newItems: [TripItem]) {
        items = newItems
    }

    func deleteCustomItem(_ item: TripItem) async {
        items.removeAll { $0.id == item.id }
        do {
            try await repo?.delete(item)
        } catch {
            logger.error("deleteCustomItem failed: \(error)")
            if let r = repo {
                items = (try? await r.fetchAll(for: trip.id)) ?? items
            }
        }
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
