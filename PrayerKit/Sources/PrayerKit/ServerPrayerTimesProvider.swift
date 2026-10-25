import Foundation

public enum PrayerTimesError: LocalizedError, Equatable {
    case noNearbyMosque
    case server(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .noNearbyMosque: "None of the mosques near you have prayer times yet."
        case .server(let statusCode): "The prayer times server had a problem (\(statusCode))."
        }
    }
}

public struct ServerPrayerTimesProvider: PrayerTimesProvider {
    public static let localServer = URL(string: "http://localhost:8000")!

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = Self.localServer, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func prayerTimes(near coordinate: Coordinate) async throws -> PrayerTimesResponse {
        let url = baseURL.appending(path: "prayer-times").appending(queryItems: [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
        ])
        let (data, response) = try await session.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.response(from: data, statusCode: statusCode)
    }

    static func response(from data: Data, statusCode: Int) throws -> PrayerTimesResponse {
        switch statusCode {
        case 200: break
        case 404: throw PrayerTimesError.noNearbyMosque
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
        let latitude: Double
        let longitude: Double
        let distanceMeters: Double
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
    let mosque: Mosque
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
        let source = TimesSource.mosque(
            PrayerKit.Mosque(
                id: mosque.id,
                name: mosque.name,
                address: mosque.address,
                coordinate: Coordinate(latitude: mosque.latitude, longitude: mosque.longitude)
            ),
            distanceInMeters: mosque.distanceMeters
        )
        return PrayerTimesResponse(source: source, days: prayerDays)
    }
}
