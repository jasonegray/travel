import Foundation
import SwiftData

@Model
final class TripItem {
    var id: UUID
    var tripId: UUID
    var masterItemId: UUID?
    var parentTripItemId: UUID?
    var clonedFromTripItemId: UUID?
    var name: String
    var category: ItemCategory
    var itemType: ItemType
    var quantity: Int
    var packingLocation: PackingLocation
    var flightAccessible: Bool
    var completedAt: Date?
    var snoozedUntil: Date?
    var feedbackFlags: [FeedbackType]
    var source: TripItemSource
    var notes: String?

    init(
        id: UUID = UUID(),
        tripId: UUID,
        masterItemId: UUID? = nil,
        parentTripItemId: UUID? = nil,
        clonedFromTripItemId: UUID? = nil,
        name: String,
        category: ItemCategory,
        itemType: ItemType = .physical,
        quantity: Int = 1,
        packingLocation: PackingLocation = .carryOn,
        flightAccessible: Bool = true,
        completedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        feedbackFlags: [FeedbackType] = [],
        source: TripItemSource = .generated,
        notes: String? = nil
    ) {
        self.id = id
        self.tripId = tripId
        self.masterItemId = masterItemId
        self.parentTripItemId = parentTripItemId
        self.clonedFromTripItemId = clonedFromTripItemId
        self.name = name
        self.category = category
        self.itemType = itemType
        self.quantity = quantity
        self.packingLocation = packingLocation
        self.flightAccessible = flightAccessible
        self.completedAt = completedAt
        self.snoozedUntil = snoozedUntil
        self.feedbackFlags = feedbackFlags
        self.source = source
        self.notes = notes
    }
}
