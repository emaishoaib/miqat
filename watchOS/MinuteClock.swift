import Foundation
import Observation

@MainActor
@Observable
final class MinuteClock {
    private(set) var now = Date.now

    init() {
        Task { [weak self] in
            while !Task.isCancelled {
                let next = Calendar.current.nextDate(after: .now, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
                    ?? .now.addingTimeInterval(60)
                try? await Task.sleep(for: .seconds(next.timeIntervalSinceNow + 0.05))
                guard let self else { return }
                self.now = .now
            }
        }
    }
}
