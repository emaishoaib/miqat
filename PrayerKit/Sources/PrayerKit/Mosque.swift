import Foundation

public struct Mosque: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let website: URL?
    public let coordinate: Coordinate

    public init(id: String, name: String, address: String, website: URL? = nil, coordinate: Coordinate) {
        self.id = id
        self.name = name
        self.address = address
        self.website = website
        self.coordinate = coordinate
    }
}

public struct NearbyMosque: Codable, Hashable, Sendable {
    public let id: String?
    public let name: String
    public let website: URL

    public static let placeFragmentPrefix = "miqat-place="

    public init(id: String?, name: String, website: URL) {
        self.id = id
        self.name = name
        self.website = website
    }

    public var websiteMarkedWithPlace: URL {
        guard let id, var components = URLComponents(url: website, resolvingAgainstBaseURL: false), components.fragment == nil else { return website }
        components.fragment = Self.placeFragmentPrefix + id
        return components.url ?? website
    }
}
