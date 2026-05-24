import Foundation
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "TripSettingsViewModel")

@Observable
final class TripSettingsViewModel {

    // MARK: - Draft state

    var activities: Set<ActivityType>
    var carryOnOnly: Bool
    var laundryAvailable: Bool
    var interacPhone: Bool
    var interacLaptop: Bool

    // MARK: - UI state

    var showConfirmation = false
    var isRegenerating = false
    var errorMessage: String?

    private let trip: TripSession
    private let originalActivities: Set<ActivityType>
    private let originalCarryOnOnly: Bool
    private let originalLaundryAvailable: Bool
    private let originalInteracPhone: Bool
    private let originalInteracLaptop: Bool

    var hasChanges: Bool {
        activities != originalActivities ||
        carryOnOnly != originalCarryOnOnly ||
        laundryAvailable != originalLaundryAvailable ||
        interacPhone != originalInteracPhone ||
        interacLaptop != originalInteracLaptop
    }

    init(trip: TripSession) {
        self.trip = trip
        let acts = Set(trip.activities)
        activities = acts
        carryOnOnly = trip.carryOnOnly
        laundryAvailable = trip.laundryAvailable
        interacPhone = trip.interacPhone
        interacLaptop = trip.interacLaptop
        originalActivities = acts
        originalCarryOnOnly = trip.carryOnOnly
        originalLaundryAvailable = trip.laundryAvailable
        originalInteracPhone = trip.interacPhone
        originalInteracLaptop = trip.interacLaptop
    }

    // MARK: - Actions

    func requestSave() {
        guard hasChanges else { return }
        showConfirmation = true
    }

    func revertChanges() {
        activities = originalActivities
        carryOnOnly = originalCarryOnOnly
        laundryAvailable = originalLaundryAvailable
        interacPhone = originalInteracPhone
        interacLaptop = originalInteracLaptop
    }

    @MainActor
    func applyAndRegenerate(
        sessions: any TripSessionRepository,
        tripItems: any TripItemRepository,
        masterItems: any MasterItemRepository
    ) async -> [TripItem]? {
        isRegenerating = true
        defer { isRegenerating = false }

        let prevActivities = trip.activities
        let prevCarryOnOnly = trip.carryOnOnly
        let prevLaundryAvailable = trip.laundryAvailable
        let prevInteracPhone = trip.interacPhone
        let prevInteracLaptop = trip.interacLaptop
        let prevBusiness = trip.business
        let prevUpdatedAt = trip.updatedAt

        trip.activities = Array(activities)
        trip.carryOnOnly = carryOnOnly
        trip.laundryAvailable = laundryAvailable
        trip.interacPhone = interacPhone
        trip.interacLaptop = interacLaptop
        trip.business = activities.contains(.conference)
        trip.updatedAt = Date()

        do {
            let existing = try await tripItems.fetchAll(for: trip.id)
            let activeItems = try await masterItems.fetchActive()
            let generated = ChecklistEngine().generateItems(for: trip, from: activeItems)

            // Build lookup: masterItemId → existing generated TripItem
            var existingByMasterId: [UUID: TripItem] = [:]
            for item in existing where item.source != .manual {
                if let mid = item.masterItemId {
                    existingByMasterId[mid] = item
                }
            }
            let newMasterIds = Set(generated.compactMap(\.masterItemId))

            // Manual items are always preserved
            var finalItems: [TripItem] = existing.filter { $0.source == .manual }

            for newItem in generated {
                guard let mid = newItem.masterItemId else { continue }
                if let survivor = existingByMasterId[mid] {
                    // Preserve completedAt; update mutable fields
                    survivor.quantity = newItem.quantity
                    survivor.packingLocation = newItem.packingLocation
                    try await tripItems.update(survivor)
                    finalItems.append(survivor)
                } else {
                    try await tripItems.insert(newItem)
                    finalItems.append(newItem)
                }
            }

            // Remove generated items that are no longer in the new set
            for item in existing where item.source != .manual {
                guard let mid = item.masterItemId, !newMasterIds.contains(mid) else { continue }
                try await tripItems.delete(item)
            }

            try await sessions.update(trip)
            return finalItems

        } catch {
            logger.error("applyAndRegenerate failed: \(error)")
            trip.activities = prevActivities
            trip.carryOnOnly = prevCarryOnOnly
            trip.laundryAvailable = prevLaundryAvailable
            trip.interacPhone = prevInteracPhone
            trip.interacLaptop = prevInteracLaptop
            trip.business = prevBusiness
            trip.updatedAt = prevUpdatedAt
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
