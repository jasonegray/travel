import Foundation
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "TripInfoViewModel")

@Observable
final class TripInfoViewModel {
    let trip: TripSession
    private var repo: (any TripInfoRepository)?

    // Outbound flight
    var outboundAirline: String = ""
    var outboundFlightNumber: String = ""
    var outboundDepartureAirport: String = ""
    var outboundDepartureTime: Date?
    var outboundArrivalAirport: String = ""
    var outboundArrivalTime: Date?

    // Return flight
    var returnAirline: String = ""
    var returnFlightNumber: String = ""
    var returnDepartureAirport: String = ""
    var returnDepartureTime: Date?
    var returnArrivalAirport: String = ""
    var returnArrivalTime: Date?

    // Booking
    var bookingReference: String = ""
    var outboundSeatNumber: String = ""
    var returnSeatNumber: String = ""

    // Accommodation
    var accommodationName: String = ""
    var accommodationAddress: String = ""
    var checkIn: Date?
    var checkOut: Date?
    var accommodationConfirmation: String = ""
    var accommodationPhone: String = ""

    private(set) var isSaving = false

    init(trip: TripSession) {
        self.trip = trip
        loadFromModel()
    }

    func loadRepository(_ repo: any TripInfoRepository) {
        self.repo = repo
    }

    private func loadFromModel() {
        guard let info = trip.tripInfo else { return }
        outboundAirline          = info.outboundAirline ?? ""
        outboundFlightNumber     = info.outboundFlightNumber ?? ""
        outboundDepartureAirport = info.outboundDepartureAirport ?? ""
        outboundDepartureTime    = info.outboundDepartureTime
        outboundArrivalAirport   = info.outboundArrivalAirport ?? ""
        outboundArrivalTime      = info.outboundArrivalTime
        returnAirline            = info.returnAirline ?? ""
        returnFlightNumber       = info.returnFlightNumber ?? ""
        returnDepartureAirport   = info.returnDepartureAirport ?? ""
        returnDepartureTime      = info.returnDepartureTime
        returnArrivalAirport     = info.returnArrivalAirport ?? ""
        returnArrivalTime        = info.returnArrivalTime
        bookingReference         = info.bookingReference ?? ""
        outboundSeatNumber       = info.outboundSeatNumber ?? ""
        returnSeatNumber         = info.returnSeatNumber ?? ""
        accommodationName        = info.accommodationName ?? ""
        accommodationAddress     = info.accommodationAddress ?? ""
        checkIn                  = info.checkIn
        checkOut                 = info.checkOut
        accommodationConfirmation = info.accommodationConfirmation ?? ""
        accommodationPhone       = info.accommodationPhone ?? ""
    }

    func save() async {
        guard let repo else { return }
        isSaving = true
        defer { isSaving = false }

        if let existing = trip.tripInfo {
            applyFormValues(to: existing)
            do {
                try await repo.update(existing)
            } catch {
                logger.error("TripInfo update failed: \(error)")
            }
        } else {
            let info = TripInfo(tripId: trip.id)
            applyFormValues(to: info)
            trip.tripInfo = info
            do {
                try await repo.insert(info)
            } catch {
                logger.error("TripInfo insert failed: \(error)")
                trip.tripInfo = nil
            }
        }
    }

    private func applyFormValues(to info: TripInfo) {
        info.outboundAirline          = outboundAirline.nilIfEmpty
        info.outboundFlightNumber     = outboundFlightNumber.nilIfEmpty
        info.outboundDepartureAirport = outboundDepartureAirport.nilIfEmpty
        info.outboundDepartureTime    = outboundDepartureTime
        info.outboundArrivalAirport   = outboundArrivalAirport.nilIfEmpty
        info.outboundArrivalTime      = outboundArrivalTime
        info.returnAirline            = returnAirline.nilIfEmpty
        info.returnFlightNumber       = returnFlightNumber.nilIfEmpty
        info.returnDepartureAirport   = returnDepartureAirport.nilIfEmpty
        info.returnDepartureTime      = returnDepartureTime
        info.returnArrivalAirport     = returnArrivalAirport.nilIfEmpty
        info.returnArrivalTime        = returnArrivalTime
        info.bookingReference         = bookingReference.nilIfEmpty
        info.outboundSeatNumber       = outboundSeatNumber.nilIfEmpty
        info.returnSeatNumber         = returnSeatNumber.nilIfEmpty
        info.accommodationName        = accommodationName.nilIfEmpty
        info.accommodationAddress     = accommodationAddress.nilIfEmpty
        info.checkIn                  = checkIn
        info.checkOut                 = checkOut
        info.accommodationConfirmation = accommodationConfirmation.nilIfEmpty
        info.accommodationPhone       = accommodationPhone.nilIfEmpty
        info.updatedAt                = Date()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
