import Foundation

public struct PrayerTime: Codable, Hashable, Sendable {
    public let prayer: Prayer
    public let begins: Date
    public let jamaat: Date?

    public init(prayer: Prayer, begins: Date, jamaat: Date? = nil) {
        self.prayer = prayer
        self.begins = begins
        self.jamaat = jamaat
    }
}
