import Foundation

public enum PrayerUrgency: Sendable {
    case normal
    case soon
    case imminent

    public static let soonThreshold: TimeInterval = 30 * 60
    public static let imminentThreshold: TimeInterval = 15 * 60

    public init(timeUntilNext: TimeInterval) {
        switch timeUntilNext {
        case ...Self.imminentThreshold: self = .imminent
        case ...Self.soonThreshold: self = .soon
        default: self = .normal
        }
    }
}
