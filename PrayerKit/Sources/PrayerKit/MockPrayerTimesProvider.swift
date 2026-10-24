import CoreLocation
import Foundation

public struct MockPrayerTimesProvider: PrayerTimesProvider {
    public static let sampleMosque = Mosque(
        id: "example-masjid",
        name: "Example Masjid",
        address: "Solihull, West Midlands",
        coordinate: Coordinate(latitude: 52.4118, longitude: -1.7776)
    )

    private static let schedule: [(prayer: Prayer, begins: (hour: Int, minute: Int), jamaat: (hour: Int, minute: Int)?)] = [
        (.fajr, (5, 52), (6, 30)),
        (.sunrise, (7, 48), nil),
        (.dhuhr, (12, 49), (13, 30)),
        (.asr, (15, 14), (15, 45)),
        (.maghrib, (17, 50), (17, 55)),
        (.isha, (19, 21), (19, 45)),
    ]

    private let timeZone: TimeZone

    public init(timeZone: TimeZone = TimeZone(identifier: "Europe/London")!) {
        self.timeZone = timeZone
    }

    public func prayerTimes(near coordinate: Coordinate, from start: Date, days: Int) async throws -> PrayerTimesResponse {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let firstDay = calendar.startOfDay(for: start)

        let prayerDays = (0..<max(days, 0)).compactMap { offset -> PrayerDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let times = Self.schedule.compactMap { entry -> PrayerTime? in
                guard let begins = calendar.date(bySettingHour: entry.begins.hour, minute: entry.begins.minute, second: 0, of: day) else { return nil }
                let jamaat = entry.jamaat.flatMap { calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: day) }
                return PrayerTime(prayer: entry.prayer, begins: begins, jamaat: jamaat)
            }
            return PrayerDay(date: day, times: times)
        }

        let mosque = Self.sampleMosque
        let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: mosque.coordinate.latitude, longitude: mosque.coordinate.longitude))

        return PrayerTimesResponse(source: .mosque(mosque, distanceInMeters: distance), days: prayerDays)
    }
}
