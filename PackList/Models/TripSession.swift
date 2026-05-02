import Foundation
import SwiftData

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
    var status: TripStatus
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var items: [TripItem]

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
        status: TripStatus = .planning,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        items: [TripItem] = []
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
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }
}
