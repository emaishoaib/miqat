import Foundation
import Observation
import os
import PrayerKit
import WatchConnectivity
import WidgetKit

@MainActor
@Observable
final class WatchTimetableModel: NSObject, WCSessionDelegate {
    nonisolated static let timetableKey = "timetable"
    nonisolated static let requestTimeout = Duration.seconds(10)

    private(set) var response: PrayerTimesResponse?
    private(set) var isRefreshing = false

    private let cache: TimetableCache

    init(cache: TimetableCache = .shared) {
        self.cache = cache
        super.init()
        response = cache.load()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if let response = store(await Self.requestTimetable()) {
            self.response = response
        }
    }

    func receivePendingContent() async {
        let session = WCSession.default
        while session.activationState != .activated || session.hasContentPending {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in await self.refresh() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }

    private nonisolated func receive(_ payload: [String: Any]) {
        guard let response = store(payload[Self.timetableKey] as? Data) else { return }
        Task { @MainActor in self.response = response }
    }

    private nonisolated func store(_ data: Data?) -> PrayerTimesResponse? {
        guard let data,
              let response = try? JSONDecoder().decode(PrayerTimesResponse.self, from: data),
              response != cache.load() else { return nil }
        cache.save(response)
        WidgetCenter.shared.reloadAllTimelines()
        return response
    }

    private nonisolated static func requestTimetable() async -> Data? {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return nil }
        return await withCheckedContinuation { continuation in
            let pending = OSAllocatedUnfairLock<CheckedContinuation<Data?, Never>?>(initialState: continuation)
            let finish: @Sendable (Data?) -> Void = { data in
                pending.withLock { state in
                    defer { state = nil }
                    return state
                }?.resume(returning: data)
            }
            session.sendMessage([:]) { reply in
                finish(reply[timetableKey] as? Data)
            } errorHandler: { _ in
                finish(nil)
            }
            Task {
                try? await Task.sleep(for: requestTimeout)
                finish(nil)
            }
        }
    }
}
