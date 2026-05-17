import Foundation
import SwiftData

// Snapshot of the PackList schema as of v1.0.0 (May 2026).
// NEVER edit these class definitions — they are a permanent record of what v1 looked like.
// To add or change a model, create PackListSchemaV2 with the updated classes and write a
// MigrationStage in PackListMigrationPlan. Update the top-level typealias in the model file
// to point to the new version.
enum PackListSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [TripSession.self, TripInfo.self, MasterItem.self, TripItem.self,
         ItemInsight.self, PendingSuggestion.self]
    }

    // MARK: - TripSession

    @Model
    final class TripSession {
        var id: UUID
        var ownerId: UUID?
        var parentTripId: UUID?
        var name: String
        var destination: String
        var region: TravelRegion
        var departureDate: Date
        var returnDate: Date
        var purposes: [TripPurpose]
        var weather: WeatherProfile
        var companions: [TravelCompanion]
        var activities: [ActivityType]
        var laundryAvailable: Bool
        var carryOnOnly: Bool
        var business: Bool
        var interacPhone: Bool
        var interacLaptop: Bool
        var hasMedicalAppointment: Bool
        var manuallyCompletedAt: Date?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date
        @Relationship(deleteRule: .cascade) var items: [TripItem]
        @Relationship(deleteRule: .cascade) var tripInfo: TripInfo?

        var status: TripStatus {
            if manuallyCompletedAt != nil { return .completed }
            let today = Calendar.current.startOfDay(for: .now)
            let retDay = Calendar.current.startOfDay(for: returnDate)
            if retDay < today { return .completed }
            let depDay = Calendar.current.startOfDay(for: departureDate)
            let daysUntilDep = Calendar.current.dateComponents([.day], from: today, to: depDay).day ?? 0
            return daysUntilDep <= 7 ? .active : .planning
        }

        init(
            id: UUID = UUID(),
            ownerId: UUID? = nil,
            parentTripId: UUID? = nil,
            name: String,
            destination: String,
            region: TravelRegion = .canada,
            departureDate: Date,
            returnDate: Date,
            purposes: [TripPurpose] = [],
            weather: WeatherProfile = .mild,
            companions: [TravelCompanion] = [.solo],
            activities: [ActivityType] = [],
            laundryAvailable: Bool = false,
            carryOnOnly: Bool = false,
            business: Bool = false,
            interacPhone: Bool = false,
            interacLaptop: Bool = false,
            hasMedicalAppointment: Bool = false,
            manuallyCompletedAt: Date? = nil,
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            items: [TripItem] = [],
            tripInfo: TripInfo? = nil
        ) {
            self.id = id
            self.ownerId = ownerId
            self.parentTripId = parentTripId
            self.name = name
            self.destination = destination
            self.region = region
            self.departureDate = departureDate
            self.returnDate = returnDate
            self.purposes = purposes
            self.weather = weather
            self.companions = companions
            self.activities = activities
            self.laundryAvailable = laundryAvailable
            self.carryOnOnly = carryOnOnly
            self.business = business
            self.interacPhone = interacPhone
            self.interacLaptop = interacLaptop
            self.hasMedicalAppointment = hasMedicalAppointment
            self.manuallyCompletedAt = manuallyCompletedAt
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.items = items
            self.tripInfo = tripInfo
        }
    }

    // MARK: - TripInfo

    @Model
    final class TripInfo {
        var id: UUID
        var tripId: UUID

        var outboundAirline: String?
        var outboundFlightNumber: String?
        var outboundDepartureAirport: String?
        var outboundDepartureTime: Date?
        var outboundArrivalAirport: String?
        var outboundArrivalTime: Date?

        var returnAirline: String?
        var returnFlightNumber: String?
        var returnDepartureAirport: String?
        var returnDepartureTime: Date?
        var returnArrivalAirport: String?
        var returnArrivalTime: Date?

        var bookingReference: String?
        var outboundSeatNumber: String?
        var returnSeatNumber: String?

        var accommodationName: String?
        var accommodationAddress: String?
        var checkIn: Date?
        var checkOut: Date?
        var accommodationConfirmation: String?
        var accommodationPhone: String?

        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            tripId: UUID,
            outboundAirline: String? = nil,
            outboundFlightNumber: String? = nil,
            outboundDepartureAirport: String? = nil,
            outboundDepartureTime: Date? = nil,
            outboundArrivalAirport: String? = nil,
            outboundArrivalTime: Date? = nil,
            returnAirline: String? = nil,
            returnFlightNumber: String? = nil,
            returnDepartureAirport: String? = nil,
            returnDepartureTime: Date? = nil,
            returnArrivalAirport: String? = nil,
            returnArrivalTime: Date? = nil,
            bookingReference: String? = nil,
            outboundSeatNumber: String? = nil,
            returnSeatNumber: String? = nil,
            accommodationName: String? = nil,
            accommodationAddress: String? = nil,
            checkIn: Date? = nil,
            checkOut: Date? = nil,
            accommodationConfirmation: String? = nil,
            accommodationPhone: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.tripId = tripId
            self.outboundAirline = outboundAirline
            self.outboundFlightNumber = outboundFlightNumber
            self.outboundDepartureAirport = outboundDepartureAirport
            self.outboundDepartureTime = outboundDepartureTime
            self.outboundArrivalAirport = outboundArrivalAirport
            self.outboundArrivalTime = outboundArrivalTime
            self.returnAirline = returnAirline
            self.returnFlightNumber = returnFlightNumber
            self.returnDepartureAirport = returnDepartureAirport
            self.returnDepartureTime = returnDepartureTime
            self.returnArrivalAirport = returnArrivalAirport
            self.returnArrivalTime = returnArrivalTime
            self.bookingReference = bookingReference
            self.outboundSeatNumber = outboundSeatNumber
            self.returnSeatNumber = returnSeatNumber
            self.accommodationName = accommodationName
            self.accommodationAddress = accommodationAddress
            self.checkIn = checkIn
            self.checkOut = checkOut
            self.accommodationConfirmation = accommodationConfirmation
            self.accommodationPhone = accommodationPhone
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    // MARK: - MasterItem

    @Model
    final class MasterItem {
        var id: UUID
        var ownerId: UUID?
        var requiredByItemId: UUID?
        var name: String
        var category: ItemCategory
        var itemType: ItemType
        var tags: [ItemTag]
        var flightAccessible: Bool
        var isAlwaysInclude: Bool
        var defaultQuantity: Int
        var packingLocation: PackingLocation?
        var recommendedTiming: TaskTiming?
        var isActive: Bool
        var source: ItemSource
        var notes: String?
        var quantityRules: [QuantityRule]
        var replaceabilityRules: [ReplaceabilityRule]
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            ownerId: UUID? = nil,
            requiredByItemId: UUID? = nil,
            name: String,
            category: ItemCategory,
            itemType: ItemType = .physical,
            tags: [ItemTag] = [],
            flightAccessible: Bool = true,
            isAlwaysInclude: Bool = false,
            defaultQuantity: Int = 1,
            packingLocation: PackingLocation? = nil,
            recommendedTiming: TaskTiming? = nil,
            isActive: Bool = true,
            source: ItemSource = .user,
            notes: String? = nil,
            quantityRules: [QuantityRule] = [],
            replaceabilityRules: [ReplaceabilityRule] = [],
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.ownerId = ownerId
            self.requiredByItemId = requiredByItemId
            self.name = name
            self.category = category
            self.itemType = itemType
            self.tags = tags
            self.flightAccessible = flightAccessible
            self.isAlwaysInclude = isAlwaysInclude
            self.defaultQuantity = defaultQuantity
            self.packingLocation = packingLocation
            self.recommendedTiming = recommendedTiming
            self.isActive = isActive
            self.source = source
            self.notes = notes
            self.quantityRules = quantityRules
            self.replaceabilityRules = replaceabilityRules
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    // MARK: - TripItem

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
        var recommendedTiming: TaskTiming?
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
            recommendedTiming: TaskTiming? = nil,
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
            self.recommendedTiming = recommendedTiming
            self.feedbackFlags = feedbackFlags
            self.source = source
            self.notes = notes
        }
    }

    // MARK: - ItemInsight

    @Model
    final class ItemInsight {
        var id: UUID
        var masterItemId: UUID
        var tripPurpose: TripPurpose
        var region: TravelRegion
        var timesIncluded: Int
        var timesCompleted: Int
        var timesMissedPostTrip: Int
        var timesMarkedUnnecessary: Int
        var quantityOverrides: [Int]
        var lastUpdated: Date

        init(
            id: UUID = UUID(),
            masterItemId: UUID,
            tripPurpose: TripPurpose,
            region: TravelRegion,
            timesIncluded: Int = 0,
            timesCompleted: Int = 0,
            timesMissedPostTrip: Int = 0,
            timesMarkedUnnecessary: Int = 0,
            quantityOverrides: [Int] = [],
            lastUpdated: Date = Date()
        ) {
            self.id = id
            self.masterItemId = masterItemId
            self.tripPurpose = tripPurpose
            self.region = region
            self.timesIncluded = timesIncluded
            self.timesCompleted = timesCompleted
            self.timesMissedPostTrip = timesMissedPostTrip
            self.timesMarkedUnnecessary = timesMarkedUnnecessary
            self.quantityOverrides = quantityOverrides
            self.lastUpdated = lastUpdated
        }
    }

    // MARK: - PendingSuggestion

    @Model
    final class PendingSuggestion {
        var id: UUID
        var targetItemId: UUID?
        var tripId: UUID?
        var type: SuggestionType
        var proposedChange: String
        var reasoning: String
        var status: SuggestionStatus
        var createdAt: Date

        init(
            id: UUID = UUID(),
            targetItemId: UUID? = nil,
            tripId: UUID? = nil,
            type: SuggestionType,
            proposedChange: String,
            reasoning: String,
            status: SuggestionStatus = .pending,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.targetItemId = targetItemId
            self.tripId = tripId
            self.type = type
            self.proposedChange = proposedChange
            self.reasoning = reasoning
            self.status = status
            self.createdAt = createdAt
        }
    }
}
