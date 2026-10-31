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
