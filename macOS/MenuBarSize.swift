enum MenuBarSize: String, CaseIterable {
    static let key = "menuBarSize"

    case compact
    case large

    var name: String {
        switch self {
        case .compact: "Compact"
        case .large: "Large"
        }
    }
}
