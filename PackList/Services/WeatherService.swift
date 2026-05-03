import Foundation
import CoreLocation

struct WeatherService {

    static func fetchProfile(
        for coordinate: CLLocationCoordinate2D,
        from departure: Date,
        to returnDate: Date
    ) async -> WeatherProfile {
        let daysOut = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: departure)
        ).day ?? 0

        do {
            return daysOut <= 14
                ? try await forecastProfile(coordinate: coordinate, from: departure, to: returnDate)
                : try await historicalProfile(coordinate: coordinate, from: departure, to: returnDate)
        } catch {
            return .mild
        }
    }

    // MARK: - Forecast (trips within ~2 weeks)

    private static func forecastProfile(
        coordinate: CLLocationCoordinate2D,
        from start: Date,
        to end: Date
    ) async throws -> WeatherProfile {
        let url = try buildURL(
            base: "https://api.open-meteo.com/v1/forecast",
            coordinate: coordinate,
            start: start, end: end,
            extra: "daily=temperature_2m_max,precipitation_probability_max&forecast_days=16"
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        let r = try JSONDecoder().decode(ForecastResponse.self, from: data)
        let avgTemp   = average(r.daily.temperature2mMax) ?? 15
        let avgPrecip = average(r.daily.precipitationProbabilityMax) ?? 0
        return profile(avgTemp: avgTemp, avgPrecip: avgPrecip)
    }

    // MARK: - Historical (same dates, prior year)

    private static func historicalProfile(
        coordinate: CLLocationCoordinate2D,
        from start: Date,
        to end: Date
    ) async throws -> WeatherProfile {
        let cal = Calendar.current
        let histStart  = cal.date(byAdding: .year, value: -1, to: start) ?? start
        let histEnd    = cal.date(byAdding: .year, value: -1, to: end) ?? end
        let url = try buildURL(
            base: "https://archive-api.open-meteo.com/v1/archive",
            coordinate: coordinate,
            start: histStart, end: histEnd,
            extra: "daily=temperature_2m_max,precipitation_sum"
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        let r = try JSONDecoder().decode(ArchiveResponse.self, from: data)
        let avgTemp      = average(r.daily.temperature2mMax) ?? 15
        let avgPrecipMm  = average(r.daily.precipitationSum) ?? 0
        // >3 mm/day average ≈ rainy; convert to a pseudo-probability for shared mapping
        return profile(avgTemp: avgTemp, avgPrecip: avgPrecipMm > 3 ? 60 : 10)
    }

    // MARK: - Shared mapping

    private static func profile(avgTemp: Double, avgPrecip: Double) -> WeatherProfile {
        if avgPrecip > 50 { return .rainy }
        if avgTemp > 28   { return .hot }
        if avgTemp > 20   { return .warm }
        if avgTemp > 10   { return .mild }
        return .cold
    }

    private static func average(_ values: [Double?]) -> Double? {
        let defined = values.compactMap { $0 }
        guard !defined.isEmpty else { return nil }
        return defined.reduce(0, +) / Double(defined.count)
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private static func buildURL(
        base: String,
        coordinate: CLLocationCoordinate2D,
        start: Date,
        end: Date,
        extra: String
    ) throws -> URL {
        let str = "\(base)?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&\(extra)&start_date=\(isoDate(start))&end_date=\(isoDate(end))&timezone=auto"
        guard let url = URL(string: str) else { throw URLError(.badURL) }
        return url
    }
}

// MARK: - Response models

private struct ForecastResponse: Decodable {
    struct Daily: Decodable {
        let temperature2mMax: [Double?]
        let precipitationProbabilityMax: [Double?]
        enum CodingKeys: String, CodingKey {
            case temperature2mMax = "temperature_2m_max"
            case precipitationProbabilityMax = "precipitation_probability_max"
        }
    }
    let daily: Daily
}

private struct ArchiveResponse: Decodable {
    struct Daily: Decodable {
        let temperature2mMax: [Double?]
        let precipitationSum: [Double?]
        enum CodingKeys: String, CodingKey {
            case temperature2mMax = "temperature_2m_max"
            case precipitationSum = "precipitation_sum"
        }
    }
    let daily: Daily
}
