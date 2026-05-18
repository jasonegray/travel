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
