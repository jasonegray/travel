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
    var hasMedicalAppointment: Bool
    var isFlyingTrip: Bool = true
    var isArchived: Bool = false
    var manuallyCompletedAt: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var items: [TripItem]
    @Relationship(deleteRule: .cascade) var tripInfo: TripInfo?

    var status: TripStatus {
        if isArchived { return .archived }
        if manuallyCompletedAt != nil { return .completed }
        let today = Calendar.current.startOfDay(for: .now)
        let retDay = Calendar.current.startOfDay(for: returnDate)
        if retDay < today { return .completed }
        let depDay = Calendar.current.startOfDay(for: departureDate)
        let daysUntilDep = Calendar.current.dateComponents([.day], from: today, to: depDay).day ?? 0
        return daysUntilDep <= 7 ? .active : .planning
    }

    /// True once the trip has passed its midpoint, indicating the traveler may
    /// be returning soon or is already back. Drives the "Back from your trip?"
    /// prompt so it never appears on trips that haven't departed or are only
    /// just underway. Once `returnDate` passes, `status` becomes `.completed`.
    var isPastMidpoint: Bool {
        let midpoint = departureDate.addingTimeInterval(
            returnDate.timeIntervalSince(departureDate) / 2
        )
        return Date.now >= midpoint
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
        isFlyingTrip: Bool = true,
        isArchived: Bool = false,
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
        self.isFlyingTrip = isFlyingTrip
        self.isArchived = isArchived
        self.manuallyCompletedAt = manuallyCompletedAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
        self.tripInfo = tripInfo
    }
}
