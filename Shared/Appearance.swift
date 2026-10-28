import Foundation
import PrayerKit

enum Appearance: String, CaseIterable {
    static let key = "appearance"
    static var store: UserDefaults? {
        UserDefaults(suiteName: TimetableCache.appGroup)
    }

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

    func usesDayColours(sunIsUp: Bool, systemIsDark: Bool) -> Bool {
        switch self {
        case .sun: sunIsUp
        case .system: !systemIsDark
        case .day: true
        case .night: false
        }
    }
}
