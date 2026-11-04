public enum TimesSource: Codable, Hashable, Sendable {
    case mosque(Mosque, distanceInMeters: Double)
    case city(name: String, method: String? = nil, asrSchool: String? = nil)

    public func mosqueToCheck(nearby: NearbyMosque?) -> NearbyMosque? {
        switch self {
        case .mosque(let mosque, _): mosque.website.map { NearbyMosque(id: mosque.id, name: mosque.name, website: $0) }
        case .city: nearby
        }
    }
}
