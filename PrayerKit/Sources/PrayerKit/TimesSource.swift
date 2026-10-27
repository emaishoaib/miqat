public enum TimesSource: Codable, Hashable, Sendable {
    case mosque(Mosque, distanceInMeters: Double)
    case city(name: String, method: String? = nil, asrSchool: String? = nil)
}
