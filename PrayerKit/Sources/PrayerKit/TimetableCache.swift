import Foundation

public struct TimetableCache: Sendable {
    public static let appGroup = "group.com.mashoaib.miqat"
    public static let shared = TimetableCache(suiteName: appGroup)

    private static let key = "timetable"

    private let suiteName: String

    public init(suiteName: String) {
        self.suiteName = suiteName
    }

    public func save(_ response: PrayerTimesResponse) {
        defaults?.set(try? JSONEncoder().encode(response), forKey: Self.key)
    }

    public func load() -> PrayerTimesResponse? {
        defaults?.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(PrayerTimesResponse.self, from: $0) }
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
