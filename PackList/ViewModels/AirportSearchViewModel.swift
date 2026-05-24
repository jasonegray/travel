import Foundation

struct Airport: Identifiable, Hashable {
    let iata: String
    let city: String
    let name: String
    let country: String

    var id: String { iata }
    var displayName: String { "\(city) — \(iata)" }
}

@Observable
final class AirportSearchViewModel {
    var searchText = ""
    private let airports: [Airport]

    init() {
        airports = Self.loadAirports()
    }

    var results: [Airport] {
        guard !searchText.isEmpty else { return airports }
        let query = searchText.lowercased()
        return airports.filter {
            $0.iata.lowercased().hasPrefix(query) ||
            $0.city.lowercased().contains(query) ||
            $0.name.lowercased().contains(query)
        }
    }

    private static func loadAirports() -> [Airport] {
        guard let url = Bundle.main.url(forResource: "airports", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([AirportEntry].self, from: data)
        else { return [] }
        return entries.map { Airport(iata: $0.iata, city: $0.city, name: $0.name, country: $0.country) }
    }
}

private struct AirportEntry: Decodable {
    let iata: String
    let city: String
    let name: String
    let country: String
}
