import Foundation
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "HomeViewModel")

@Observable
final class HomeViewModel {

    private(set) var heroTrip: TripSession?
    private(set) var otherUpcomingTrips: [TripSession] = []
    private(set) var completedTrips: [TripSession] = []
    private(set) var tripProgressMap: [UUID: (packed: Int, total: Int)] = [:]
    private(set) var isLoading = false

    // MARK: - Load

    func load(sessions: any TripSessionRepository) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await sessions.fetchAll()
            let nonArchived = all.filter { $0.status != .archived }

            let nonCompleted = nonArchived
                .filter { $0.status != .completed }
                .sorted { $0.departureDate < $1.departureDate }
            let completed = nonArchived
                .filter { $0.status == .completed }
                .sorted { $0.departureDate > $1.departureDate }

            // Hero: soonest active trip; fall back to soonest planning trip
            let active = nonCompleted.filter { $0.status == .active }
            heroTrip = active.first ?? nonCompleted.first

            otherUpcomingTrips = heroTrip.map { hero in
                nonCompleted.filter { $0.id != hero.id }
            } ?? []
            completedTrips = completed

            // Progress for every trip via SwiftData relationship — used by strip/completed cards
            var map: [UUID: (packed: Int, total: Int)] = [:]
            for trip in nonArchived {
                let physical = trip.items.filter { $0.itemType == .physical }
                map[trip.id] = (
                    packed: physical.filter { $0.completedAt != nil }.count,
                    total: physical.count
                )
            }
            tripProgressMap = map
        } catch {
            logger.error("Load failed: \(error)")
        }
    }

    // MARK: - Hero trip task actions

    func toggle(item: TripItem) {
        item.completedAt = item.completedAt == nil ? Date() : nil
    }

    func save(item: TripItem, repository: any TripItemRepository) async {
        do {
            try await repository.update(item)
        } catch {
            logger.error("Save failed: \(error)")
            toggle(item: item)
        }
    }

    // MARK: - Per-trip computations (accept @Query items so the caller drives reactivity)

    func packingProgress(from items: [TripItem]) -> (completed: Int, total: Int) {
        let physical = items.filter { $0.itemType == .physical }
        return (physical.filter { $0.completedAt != nil }.count, physical.count)
    }

    func prepProgress(from items: [TripItem]) -> (completed: Int, total: Int) {
        let tasks = items.filter { $0.itemType == .task }
        return (tasks.filter { $0.completedAt != nil }.count, tasks.count)
    }

    func bagsSummary(from items: [TripItem]) -> [(location: PackingLocation, packed: Int, total: Int)] {
        let physical = items.filter { $0.itemType == .physical }
        let grouped = Dictionary(grouping: physical, by: \.packingLocation)
        return grouped
            .map { location, locationItems in
                (location: location,
                 packed: locationItems.filter { $0.completedAt != nil }.count,
                 total: locationItems.count)
            }
            .sorted {
                let lhsDone = $0.packed == $0.total
                let rhsDone = $1.packed == $1.total
                if lhsDone != rhsDone { return !lhsDone }
                return $0.location.sortOrder < $1.location.sortOrder
            }
    }

    func upNextTasks(from items: [TripItem], departure: Date) -> [TripItem] {
        Array(
            items
                .filter { $0.itemType == .task && $0.completedAt == nil }
                .sorted {
                    let aOrd = $0.recommendedTiming?.sortOrdinal ?? 99
                    let bOrd = $1.recommendedTiming?.sortOrdinal ?? 99
                    if aOrd != bOrd { return aOrd < bOrd }
                    return recommendedByDate($0.recommendedTiming, departure: departure)
                        < recommendedByDate($1.recommendedTiming, departure: departure)
                }
                .prefix(3)
        )
    }

    // MARK: - Delete

    func deleteTrip(_ trip: TripSession, sessions: any TripSessionRepository) async {
        do {
            try await sessions.delete(trip)
            await load(sessions: sessions)
        } catch {
            logger.error("deleteTrip failed: \(error)")
        }
    }

    // MARK: - Debug

    #if DEBUG
    func deleteAllTrips(sessions: any TripSessionRepository) async {
        do {
            let all = try await sessions.fetchAll()
            for trip in all { try await sessions.delete(trip) }
            heroTrip = nil
            otherUpcomingTrips = []
            completedTrips = []
            tripProgressMap = [:]
        } catch {
            logger.error("deleteAllTrips failed: \(error)")
        }
    }
    #endif

    // MARK: - Helpers

    func recommendedByDate(_ timing: TaskTiming?, departure: Date) -> Date {
        let cal = Calendar.current
        switch timing {
        case .weekBefore:      return cal.date(byAdding: .day, value: -7, to: departure) ?? departure
        case .threeDaysBefore: return cal.date(byAdding: .day, value: -3, to: departure) ?? departure
        case .dayBefore:       return cal.date(byAdding: .day, value: -1, to: departure) ?? departure
        default:               return departure
        }
    }
}
