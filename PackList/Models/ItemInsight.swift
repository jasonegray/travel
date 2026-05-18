import Foundation
import SwiftData

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
