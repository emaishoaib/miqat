import Foundation
import Observation
import PrayerKit

@MainActor
@Observable
final class TimetableModel {
    enum State {
        case loading
        case loaded(PrayerTimesResponse)
        case failed(String)
    }

    private(set) var state: State = .loading

    private let provider: any PrayerTimesProvider
    private let coordinate: Coordinate

    init(
        provider: any PrayerTimesProvider = MockPrayerTimesProvider(),
        coordinate: Coordinate = Coordinate(latitude: 52.4128, longitude: -1.7781)
    ) {
        self.provider = provider
        self.coordinate = coordinate
    }

    func load() async {
        do {
            state = .loaded(try await provider.prayerTimes(near: coordinate, from: .now, days: 2))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
