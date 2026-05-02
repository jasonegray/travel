import Foundation

struct ReplaceabilityRule: Codable {
    var regions: [TravelRegion]?
    var tripPurposes: [TripPurpose]?
    var replaceability: Replaceability
}
