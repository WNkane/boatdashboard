import Foundation
import CoreLocation

// MARK: - Weather Data Model

struct StationWeather {
    let stationName: String
    let temperature: Double   // °C
    let windSpeed: Double     // m/s
    let windDirection: Double // degrees, meteorological (0 = N, 90 = E; direction FROM which wind blows)
    let description: String   // 晴 / 多雲 / 陰 / 雨

    /// 16-point Chinese compass label for wind direction
    var windDirectionLabel: String {
        let dirs = ["北","北北東","東北","東北東","東","東南東","東南","南南東",
                    "南","南南西","西南","西西南","西","西北西","西北","北北西"]
        let i = Int((windDirection / 22.5).rounded()) % 16
        return dirs[max(0, i)]
    }

    /// Headwind component (m/s) for a given travel heading (0 = N, clockwise).
    /// Positive  → heading into the wind (headwind).
    /// Negative  → wind pushing from behind (tailwind).
    func headwindComponent(heading: Double) -> Double {
        guard windSpeed > 0, heading >= 0 else { return 0 }
        // Met. convention: windDirection is where the wind comes FROM.
        // Convert to "wind flow vector" direction:
        let windFlowDeg = (windDirection + 180).truncatingRemainder(dividingBy: 360)
        let angleRad = (heading - windFlowDeg) * .pi / 180
        return windSpeed * cos(angleRad)
    }
}

// MARK: - Weather Service

actor WeatherService {
    static let shared = WeatherService()
    private init() {}

    private let apiKey   = "CWA-650E2099-39F9-438D-A134-CF9A5DA5967E"
    private let endpoint = "https://opendata.cwa.gov.tw/api/v1/rest/datastore/O-A0001-001?format=JSON"

    // Station list is cached; individual obs values change with every call so we
    // re-fetch the whole response every 10 min (obs are bundled with station metadata).
    private var cachedStations: [ParsedStation] = []
    private var lastFetch: Date?

    func fetchNearest(latitude: Double, longitude: Double) async throws -> StationWeather {
        let now = Date()
        if cachedStations.isEmpty || lastFetch.map({ now.timeIntervalSince($0) > 600 }) == true {
            cachedStations = try await loadStations()
            lastFetch = now
        }

        let userLoc = CLLocation(latitude: latitude, longitude: longitude)
        guard let nearest = cachedStations
            .filter(\.isValid)
            .min(by: {
                userLoc.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon)) <
                userLoc.distance(from: CLLocation(latitude: $1.lat, longitude: $1.lon))
            })
        else { throw URLError(.cannotParseResponse) }

        return StationWeather(
            stationName: nearest.name,
            temperature: nearest.temperature,
            windSpeed:   nearest.windSpeed,
            windDirection: nearest.windDirection,
            description: nearest.weather
        )
    }

    private func loadStations() async throws -> [ParsedStation] {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var req = URLRequest(url: url,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: 20)
        req.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return ParsedStation.parse(data: data)
    }
}

// MARK: - Internal parsed model

struct ParsedStation {
    let name: String
    let lat: Double
    let lon: Double
    let temperature: Double  // -99 = no data
    let windSpeed: Double    // -99 = no data
    let windDirection: Double
    let weather: String

    var isValid: Bool {
        temperature > -90 && windSpeed >= 0 && lat != 0 && lon != 0
    }

    static func parse(data: Data) -> [ParsedStation] {
        guard let raw = try? JSONDecoder().decode(CWAResponse.self, from: data) else { return [] }
        return raw.records.Station.compactMap { s in
            guard let wgs = s.GeoInfo.Coordinates.first(where: { $0.CoordinateName == "WGS84" }),
                  let lat = Double(wgs.StationLatitude),
                  let lon = Double(wgs.StationLongitude)
            else { return nil }
            let we = s.WeatherElement
            return ParsedStation(
                name: s.StationName,
                lat: lat, lon: lon,
                temperature:   we.airTemperature,
                windSpeed:     we.windSpeed,
                windDirection: we.windDirection,
                weather:       we.weather
            )
        }
    }
}

// MARK: - Decodable JSON types

private struct CWAResponse: Decodable {
    struct Records: Decodable { let Station: [StationJSON] }
    let records: Records
}

private struct StationJSON: Decodable {
    let StationName: String
    let GeoInfo: GeoInfoJSON
    let WeatherElement: WeatherElementJSON
}

private struct GeoInfoJSON: Decodable {
    let Coordinates: [CoordJSON]
}

private struct CoordJSON: Decodable {
    let CoordinateName: String
    let StationLatitude: String
    let StationLongitude: String
}

private struct WeatherElementJSON: Decodable {
    let weather: String
    let airTemperature: Double
    let windDirection: Double
    let windSpeed: Double

    enum CodingKeys: String, CodingKey {
        case weather        = "Weather"
        case airTemperature = "AirTemperature"
        case windDirection  = "WindDirection"
        case windSpeed      = "WindSpeed"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weather        = (try? c.decode(String.self, forKey: .weather)) ?? ""
        airTemperature = Self.flex(c, .airTemperature)
        windDirection  = Self.flex(c, .windDirection)
        windSpeed      = Self.flex(c, .windSpeed)
    }

    /// Handles both numeric and string-encoded values (CWA sometimes returns "-99" as String).
    private static func flex(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double {
        if let v = try? c.decode(Double.self, forKey: k) { return v }
        if let s = try? c.decode(String.self, forKey: k), let v = Double(s) { return v }
        return -99
    }
}
