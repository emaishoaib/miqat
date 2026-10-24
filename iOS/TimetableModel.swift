import Foundation
import Observation
import PrayerKit

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

    init(provider: any PrayerTimesProvider = MockPrayerTimesProvider()) {
        self.provider = provider
    }

    func load() async {
        state = .loading
        do {
            let coordinate = try await CurrentLocation.coordinate()
            state = .loaded(try await provider.prayerTimes(near: coordinate, from: .now, days: 2))
        } catch {
            state = .failed(error)
        }
    }
}
