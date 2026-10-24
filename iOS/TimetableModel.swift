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

    private(set) var state: State = .loading

    private let provider: any PrayerTimesProvider
    private let cache: TimetableCache

    init(provider: any PrayerTimesProvider = MockPrayerTimesProvider(), cache: TimetableCache = .shared) {
        self.provider = provider
        self.cache = cache
        if let cached = cache.load() {
            state = .loaded(cached)
        }
    }

    func load() async {
        do {
            let coordinate = try await CurrentLocation.coordinate()
            let response = try await provider.prayerTimes(near: coordinate, from: .now, days: 7)
            cache.save(response)
            WidgetCenter.shared.reloadAllTimelines()
            state = .loaded(response)
        } catch {
            if case .loaded = state { return }
            state = .failed(error)
        }
    }
}
