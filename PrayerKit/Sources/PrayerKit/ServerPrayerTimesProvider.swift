import Foundation

public enum PrayerTimesError: LocalizedError, Equatable {
    case unavailable
    case server(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .unavailable: "Unable to get prayer times."
        case .server(let statusCode): "The prayer times server had a problem (\(statusCode))."
        }
    }
}

public struct ServerPrayerTimesProvider: PrayerTimesProvider {
    public static let localServer = URL(string: "http://localhost:8000")!

    public static var configuredServer: URL {
        (Bundle.main.object(forInfoDictionaryKey: "MiqatServerURL") as? String)
            .flatMap(URL.init(string:)) ?? localServer
    }

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = Self.configuredServer, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func prayerTimes(near coordinate: Coordinate, ifChangedSince version: String?) async throws -> PrayerTimesResponse? {
        let url = baseURL.appending(path: "prayer-times").appending(queryItems: [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
        ])
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        if let version {
            request.setValue("\"\(version)\"", forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.response(from: data, statusCode: statusCode)
    }

    static func response(from data: Data, statusCode: Int) throws -> PrayerTimesResponse? {
        switch statusCode {
        case 200: break
        case 304: return nil
        case 404: throw PrayerTimesError.unavailable
        default: throw PrayerTimesError.server(statusCode: statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ServerTimetable.self, from: data).response()
    }
}

private struct ServerTimetable: Decodable {
    struct Mosque: Decodable {
        let id: String
        let name: String
        let address: String
        let website: URL?
        let latitude: Double
        let longitude: Double
        let distanceMeters: Double
    }

    struct City: Decodable {
        let id: String
        let name: String
        let method: String?
        let asrSchool: String?
    }

    struct Day: Decodable {
        let date: String
        let times: [Time]
    }

    struct Time: Decodable {
        let prayer: Prayer
        let begins: Date
        let jamaat: Date?
    }

    let version: String
    let mosque: Mosque?
    let city: City?
    let timeZone: String
    let days: [Day]

    func response() throws -> PrayerTimesResponse {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .current
        let dateFormat = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()

        let prayerDays = try days.map { day in
            PrayerDay(
                date: calendar.startOfDay(for: try dateFormat.parse(day.date)),
                times: day.times.map { PrayerTime(prayer: $0.prayer, begins: $0.begins, jamaat: $0.jamaat) }
            )
        }
        return PrayerTimesResponse(source: try source(), days: prayerDays, version: version)
    }

    private func source() throws -> TimesSource {
        if let mosque {
            return .mosque(
                PrayerKit.Mosque(
                    id: mosque.id,
                    name: mosque.name,
                    address: mosque.address,
                    website: mosque.website,
                    coordinate: Coordinate(latitude: mosque.latitude, longitude: mosque.longitude)
                ),
                distanceInMeters: mosque.distanceMeters
            )
        }
        if let city {
            return .city(name: city.name, method: city.method, asrSchool: city.asrSchool)
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "The timetable has neither a mosque nor a city.")
        )
    }
}
