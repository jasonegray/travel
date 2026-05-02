import Foundation

@Observable
final class HomeViewModel {

    private(set) var activeTrip: TripSession?
    private(set) var items: [TripItem] = []
    private(set) var isLoading = false

    func load(sessions: any TripSessionRepository,
              tripItems: any TripItemRepository) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let active = try await sessions.fetch(status: .active)
            let planning = try await sessions.fetch(status: .planning)
            activeTrip = active.first ?? planning.first
            if let trip = activeTrip {
                items = try await tripItems.fetchAll(for: trip.id)
            } else {
                items = []
            }
        } catch {
            print("[HomeViewModel] Load failed: \(error)")
        }
    }

    // MARK: - Computed

    var packingProgress: (completed: Int, total: Int) {
        let physical = items.filter { $0.itemType == .physical }
        return (physical.filter { $0.completedAt != nil }.count, physical.count)
    }

    var prepProgress: (completed: Int, total: Int) {
        let tasks = items.filter { $0.itemType == .task }
        return (tasks.filter { $0.completedAt != nil }.count, tasks.count)
    }

    var bagsSummary: [(location: PackingLocation, packed: Int, total: Int)] {
        let physical = items.filter { $0.itemType == .physical }
        let grouped = Dictionary(grouping: physical, by: \.packingLocation)
        return grouped
            .map { location, locationItems in
                (location: location,
                 packed: locationItems.filter { $0.completedAt != nil }.count,
                 total: locationItems.count)
            }
            .sorted { $0.location.sortOrder < $1.location.sortOrder }
    }

    var upNextTasks: [TripItem] {
        guard let trip = activeTrip else { return [] }
        return Array(
            items
                .filter { $0.itemType == .task && $0.completedAt == nil }
                .sorted {
                    let aOrd = $0.recommendedTiming?.sortOrdinal ?? 99
                    let bOrd = $1.recommendedTiming?.sortOrdinal ?? 99
                    if aOrd != bOrd { return aOrd < bOrd }
                    return recommendedByDate($0.recommendedTiming, departure: trip.departureDate)
                        < recommendedByDate($1.recommendedTiming, departure: trip.departureDate)
                }
                .prefix(3)
        )
    }

    func recommendedByDate(_ timing: TaskTiming?, departure: Date) -> Date {
        let cal = Calendar.current
        switch timing {
        case .weekBefore:       return cal.date(byAdding: .day, value: -7, to: departure) ?? departure
        case .threeDaysBefore:  return cal.date(byAdding: .day, value: -3, to: departure) ?? departure
        case .dayBefore:        return cal.date(byAdding: .day, value: -1, to: departure) ?? departure
        default:                return departure
        }
    }
}
