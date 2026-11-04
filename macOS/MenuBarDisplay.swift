enum MenuBarDisplay: String, CaseIterable {
    static let key = "menuBarDisplay"

    case time
    case timeThenCountdown
    case countdown

    var name: String {
        switch self {
        case .time: "Time"
        case .timeThenCountdown: "Time, then countdown"
        case .countdown: "Countdown"
        }
    }

    func showsCountdown(secondsLeft: Int) -> Bool {
        switch self {
        case .time: false
        case .timeThenCountdown: secondsLeft < 60 * 60
        case .countdown: true
        }
    }
}
