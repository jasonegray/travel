import Foundation
import SwiftData

@Model
final class TripInfo {
    var id: UUID
    var tripId: UUID

    var outboundAirline: String?
    var outboundFlightNumber: String?
    var outboundDepartureAirport: String?
    var outboundDepartureTime: Date?
    var outboundArrivalAirport: String?

    var returnAirline: String?
    var returnFlightNumber: String?
    var returnDepartureAirport: String?
    var returnDepartureTime: Date?
    var returnArrivalAirport: String?

    var accommodationName: String?

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
        returnAirline: String? = nil,
        returnFlightNumber: String? = nil,
        returnDepartureAirport: String? = nil,
        returnDepartureTime: Date? = nil,
        returnArrivalAirport: String? = nil,
        accommodationName: String? = nil,
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
        self.returnAirline = returnAirline
        self.returnFlightNumber = returnFlightNumber
        self.returnDepartureAirport = returnDepartureAirport
        self.returnDepartureTime = returnDepartureTime
        self.returnArrivalAirport = returnArrivalAirport
        self.accommodationName = accommodationName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
