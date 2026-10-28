import Foundation
import Observation
import PrayerKit
import WidgetKit

@MainActor
@Observable
final class TimetableModel {
    enum State {
        case loading
        case loaded(PrayerTimesResponse)
        case failed(Error)
    }

    nonisolated static var nextDailyRefresh: Date {
        Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime)
            ?? .now.addingTimeInterval(24 * 60 * 60)
    }

    private(set) var state: State = .loading
    private(set) var isRefreshing = false

    private let provider: any PrayerTimesProvider
    private let cache: TimetableCache

    init(provider: any PrayerTimesProvider = ServerPrayerTimesProvider(), cache: TimetableCache = .shared) {
        self.provider = provider
        self.cache = cache
        if let cached = cache.load() {
            state = .loaded(cached)
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                await self?.load()
            }
        }
    }

    func load() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let coordinate = try await CurrentLocation.coordinate()
            cache.saveCoordinate(coordinate)
            try await refresh(near: coordinate)
        } catch {
            if !hasTimetable {
                state = .failed(error)
            }
        }
        await rescheduleNotifications()
    }

    func refreshInBackground() async {
        guard let coordinate = cache.loadCoordinate() else { return }
        try? await refresh(near: coordinate)
        await rescheduleNotifications()
    }

    private func rescheduleNotifications() async {
        #if os(iOS)
        await PrayerNotifications.reschedule(cache: cache)
        #endif
    }

    private func refresh(near coordinate: Coordinate) async throws {
        guard let response = try await provider.prayerTimes(near: coordinate, ifChangedSince: currentVersion) else {
            return
        }
        cache.save(response)
        WidgetCenter.shared.reloadAllTimelines()
        #if os(iOS)
        WatchSync.shared.send(response)
        #endif
        state = .loaded(response)
    }

    private var hasTimetable: Bool {
        if case .loaded = state { true } else { false }
    }

    private var currentVersion: String? {
        guard case .loaded(let response) = state else { return nil }
        return response.version
    }
}
