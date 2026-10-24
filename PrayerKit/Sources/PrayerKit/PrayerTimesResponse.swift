public struct PrayerTimesResponse: Codable, Hashable, Sendable {
    public let source: TimesSource
    public let days: [PrayerDay]

    public init(source: TimesSource, days: [PrayerDay]) {
        self.source = source
        self.days = days
    }
}
