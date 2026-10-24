public struct Mosque: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let coordinate: Coordinate

    public init(id: String, name: String, address: String, coordinate: Coordinate) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
    }
}
