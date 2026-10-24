public enum TimesSource: Codable, Hashable, Sendable {
    case mosque(Mosque, distanceInMeters: Double)
    case area(name: String)
}
