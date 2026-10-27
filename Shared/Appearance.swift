enum Appearance: String, CaseIterable {
    static let key = "appearance"

    case sun
    case system
    case day
    case night

    var name: String {
        switch self {
        case .sun: "Follow the sun"
        case .system: "Match the system"
        case .day: "Always day"
        case .night: "Always night"
        }
    }
}
