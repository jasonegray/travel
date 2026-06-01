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

    // Return flight
    var returnAirline: String = ""
    var returnFlightNumber: String = ""
    var returnDepartureAirport: String = ""
    var returnDepartureTime: Date?
    var returnArrivalAirport: String = ""

    // Accommodation
    var accommodationName: String = ""

    enum SaveStatus { case idle, saving, saved, failed }
    private(set) var saveStatus: SaveStatus = .idle

    private var isSaving = false
    private var saveTask: Task<Void, Never>?
    private var savedStatusTask: Task<Void, Never>?

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
        returnAirline            = info.returnAirline ?? ""
        returnFlightNumber       = info.returnFlightNumber ?? ""
        returnDepartureAirport   = info.returnDepartureAirport ?? ""
        returnDepartureTime      = info.returnDepartureTime
        returnArrivalAirport     = info.returnArrivalAirport ?? ""
        accommodationName        = info.accommodationName ?? ""
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
        saveStatus = .saving
        defer { isSaving = false }

        if let existing = trip.tripInfo {
            applyFormValues(to: existing)
            do {
                try await repo.update(existing)
                setSaved()
            } catch {
                logger.error("TripInfo update failed: \(error)")
                saveStatus = .failed
            }
        } else {
            let info = TripInfo(tripId: trip.id)
            applyFormValues(to: info)
            trip.tripInfo = info
            do {
                try await repo.insert(info)
                setSaved()
            } catch {
                logger.error("TripInfo insert failed: \(error)")
                trip.tripInfo = nil
                saveStatus = .failed
            }
        }
    }

    private func setSaved() {
        saveStatus = .saved
        savedStatusTask?.cancel()
        savedStatusTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveStatus = .idle
        }
    }

    private func applyFormValues(to info: TripInfo) {
        info.outboundAirline          = outboundAirline.nilIfEmpty
        info.outboundFlightNumber     = outboundFlightNumber.nilIfEmpty
        info.outboundDepartureAirport = outboundDepartureAirport.nilIfEmpty
        info.outboundDepartureTime    = outboundDepartureTime
        info.outboundArrivalAirport   = outboundArrivalAirport.nilIfEmpty
        info.returnAirline            = returnAirline.nilIfEmpty
        info.returnFlightNumber       = returnFlightNumber.nilIfEmpty
        info.returnDepartureAirport   = returnDepartureAirport.nilIfEmpty
        info.returnDepartureTime      = returnDepartureTime
        info.returnArrivalAirport     = returnArrivalAirport.nilIfEmpty
        info.accommodationName        = accommodationName.nilIfEmpty
        info.updatedAt                = Date()
    }

    // MARK: - Share

    var shareSummary: String {
        var lines: [String] = []

        lines.append(trip.name)
        let dep = trip.departureDate.formatted(.dateTime.month(.abbreviated).day().year())
        let ret = trip.returnDate.formatted(.dateTime.month(.abbreviated).day().year())
        lines.append("\(trip.destination) · \(dep) – \(ret)")

        if trip.isFlyingTrip {
            if let section = outboundFlightSection() {
                lines.append("")
                lines.append(contentsOf: section)
            }
            if let section = returnFlightSection() {
                lines.append("")
                lines.append(contentsOf: section)
            }
        }
        if let section = hotelSection() {
            lines.append("")
            lines.append(contentsOf: section)
        }
        return lines.joined(separator: "\n")
    }

    private func outboundFlightSection() -> [String]? {
        guard let flightNumber = outboundFlightNumber.nilIfEmpty else { return nil }

        var flightLine = outboundAirline.nilIfEmpty.map { "\($0) \(flightNumber)" } ?? flightNumber

        let dep = outboundDepartureAirport.nilIfEmpty
        let arr = outboundArrivalAirport.nilIfEmpty
        if let dep, let arr      { flightLine += " · \(dep) → \(arr)" }
        else if let dep          { flightLine += " · From: \(dep)" }
        else if let arr          { flightLine += " · To: \(arr)" }

        if let t = outboundDepartureTime { flightLine += " · \(formatDateTime(t))" }

        let flightAwareId = flightNumber.replacingOccurrences(of: " ", with: "")
        return ["OUTBOUND", flightLine, "https://flightaware.com/live/flight/\(flightAwareId)"]
    }

    private func returnFlightSection() -> [String]? {
        guard let flightNumber = returnFlightNumber.nilIfEmpty else { return nil }

        var flightLine = returnAirline.nilIfEmpty.map { "\($0) \(flightNumber)" } ?? flightNumber

        let dep = returnDepartureAirport.nilIfEmpty
        let arr = returnArrivalAirport.nilIfEmpty
        if let dep, let arr      { flightLine += " · \(dep) → \(arr)" }
        else if let dep          { flightLine += " · From: \(dep)" }
        else if let arr          { flightLine += " · To: \(arr)" }

        if let t = returnDepartureTime { flightLine += " · \(formatDateTime(t))" }

        let flightAwareId = flightNumber.replacingOccurrences(of: " ", with: "")
        return ["RETURN", flightLine, "https://flightaware.com/live/flight/\(flightAwareId)"]
    }

    private func hotelSection() -> [String]? {
        guard let name = accommodationName.nilIfEmpty else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        let encoded = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
        return ["HOTEL", name, "https://maps.apple.com/?q=\(encoded)"]
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
