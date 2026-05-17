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

    private var isSaving = false
    private var saveTask: Task<Void, Never>?

    init(trip: TripSession) {
        self.trip = trip
        loadFromModel()
    }

    func loadRepository(_ repo: any TripInfoRepository) {
        self.repo = repo
    }

    private func loadFromModel() {
        guard let info = trip.tripInfo else { return }
        outboundAirline           = info.outboundAirline ?? ""
        outboundFlightNumber      = info.outboundFlightNumber ?? ""
        outboundDepartureAirport  = info.outboundDepartureAirport ?? ""
        outboundDepartureTime     = info.outboundDepartureTime
        outboundArrivalAirport    = info.outboundArrivalAirport ?? ""
        outboundArrivalTime       = info.outboundArrivalTime
        returnAirline             = info.returnAirline ?? ""
        returnFlightNumber        = info.returnFlightNumber ?? ""
        returnDepartureAirport    = info.returnDepartureAirport ?? ""
        returnDepartureTime       = info.returnDepartureTime
        returnArrivalAirport      = info.returnArrivalAirport ?? ""
        returnArrivalTime         = info.returnArrivalTime
        bookingReference          = info.bookingReference ?? ""
        outboundSeatNumber        = info.outboundSeatNumber ?? ""
        returnSeatNumber          = info.returnSeatNumber ?? ""
        accommodationName         = info.accommodationName ?? ""
        accommodationAddress      = info.accommodationAddress ?? ""
        checkIn                   = info.checkIn
        checkOut                  = info.checkOut
        accommodationConfirmation = info.accommodationConfirmation ?? ""
        accommodationPhone        = info.accommodationPhone ?? ""
    }

    // MARK: - Auto-save

    func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    func save() async {
        guard let repo, !isSaving else { return }
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

    // MARK: - Share

    var shareSummary: String {
        var lines: [String] = []

        lines.append(trip.name)
        let dep = trip.departureDate.formatted(.dateTime.month(.abbreviated).day().year())
        let ret = trip.returnDate.formatted(.dateTime.month(.abbreviated).day().year())
        lines.append("\(trip.destination) · \(dep) – \(ret)")

        if let section = outboundFlightSection() {
            lines.append("")
            lines.append(contentsOf: section)
        }
        if let section = returnFlightSection() {
            lines.append("")
            lines.append(contentsOf: section)
        }
        if let section = accommodationSection() {
            lines.append("")
            lines.append(contentsOf: section)
        }

        return lines.joined(separator: "\n")
    }

    private func outboundFlightSection() -> [String]? {
        var fields: [String] = []

        let flightLabel = [outboundAirline.nilIfEmpty, outboundFlightNumber.nilIfEmpty].compactMap { $0 }.joined(separator: " ")
        if !flightLabel.isEmpty { fields.append(flightLabel) }

        switch (outboundDepartureAirport.nilIfEmpty, outboundArrivalAirport.nilIfEmpty) {
        case let (dep?, arr?): fields.append("\(dep) → \(arr)")
        case let (dep?, nil): fields.append("From: \(dep)")
        case let (nil, arr?): fields.append("To: \(arr)")
        default: break
        }

        if let t = outboundDepartureTime { fields.append("Departs: \(formatDateTime(t))") }
        if let t = outboundArrivalTime   { fields.append("Arrives: \(formatDateTime(t))") }
        if let s = outboundSeatNumber.nilIfEmpty { fields.append("Seat: \(s)") }
        if let r = bookingReference.nilIfEmpty   { fields.append("Booking: \(r)") }

        guard !fields.isEmpty else { return nil }
        return ["OUTBOUND FLIGHT"] + fields
    }

    private func returnFlightSection() -> [String]? {
        var fields: [String] = []

        let flightLabel = [returnAirline.nilIfEmpty, returnFlightNumber.nilIfEmpty].compactMap { $0 }.joined(separator: " ")
        if !flightLabel.isEmpty { fields.append(flightLabel) }

        switch (returnDepartureAirport.nilIfEmpty, returnArrivalAirport.nilIfEmpty) {
        case let (dep?, arr?): fields.append("\(dep) → \(arr)")
        case let (dep?, nil): fields.append("From: \(dep)")
        case let (nil, arr?): fields.append("To: \(arr)")
        default: break
        }

        if let t = returnDepartureTime { fields.append("Departs: \(formatDateTime(t))") }
        if let t = returnArrivalTime   { fields.append("Arrives: \(formatDateTime(t))") }
        if let s = returnSeatNumber.nilIfEmpty { fields.append("Seat: \(s)") }

        guard !fields.isEmpty else { return nil }
        return ["RETURN FLIGHT"] + fields
    }

    private func accommodationSection() -> [String]? {
        var fields: [String] = []

        if let n = accommodationName.nilIfEmpty    { fields.append(n) }
        if let a = accommodationAddress.nilIfEmpty { fields.append(a) }
        if let d = checkIn  { fields.append("Check-in: \(formatDateTime(d))") }
        if let d = checkOut { fields.append("Check-out: \(formatDateTime(d))") }
        if let c = accommodationConfirmation.nilIfEmpty { fields.append("Confirmation: \(c)") }
        if let p = accommodationPhone.nilIfEmpty        { fields.append("Phone: \(p)") }

        guard !fields.isEmpty else { return nil }
        return ["ACCOMMODATION"] + fields
    }

    private func formatDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
