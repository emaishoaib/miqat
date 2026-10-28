import Foundation
import PrayerKit
import WatchConnectivity

final class WatchSync: NSObject, WCSessionDelegate, Sendable {
    static let shared = WatchSync()
    static let timetableKey = "timetable"

    private let cache: TimetableCache

    init(cache: TimetableCache = .shared) {
        self.cache = cache
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ response: PrayerTimesResponse) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled,
              let payload = Self.payload(for: response) else { return }
        if session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo(payload)
        } else {
            try? session.updateApplicationContext(payload)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(cache.load().flatMap(Self.payload(for:)) ?? [:])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    private static func payload(for response: PrayerTimesResponse) -> [String: Any]? {
        (try? JSONEncoder().encode(response)).map { [timetableKey: $0] }
    }
}
