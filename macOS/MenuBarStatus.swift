import Foundation
import Observation
import PrayerKit

@MainActor
@Observable
final class MenuBarStatus {
    enum Style {
        case normal
        case alert
        case alertDimmed
    }

    private(set) var next: PrayerTime?
    private(set) var detail = ""
    private(set) var style: Style = .normal

    private let model: TimetableModel
    private var acknowledgedPrayer: Date?
    private var blinkOn = true

    init(model: TimetableModel) {
        self.model = model
        observeTimetable()
        Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = self?.refresh() else { return }
                try? await Task.sleep(for: delay)
            }
        }
    }

    func acknowledge() {
        guard style != .normal, let next else { return }
        acknowledgedPrayer = next.begins
        style = .normal
    }

    private func observeTimetable() {
        withObservationTracking {
            _ = model.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                _ = self.refresh()
                self.observeTimetable()
            }
        }
    }

    private func refresh() -> Duration {
        let now = Date.now
        guard case .loaded(let response) = model.state, let next = response.nextPrayer(after: now) else {
            self.next = nil
            style = .normal
            return .seconds(1)
        }
        self.next = next

        let remaining = next.begins.timeIntervalSince(now)
        let showsCountdown = remaining < 60 * 60
        detail = showsCountdown
            ? Self.countdown(remaining)
            : next.begins.formatted(date: .omitted, time: .shortened)

        let urgency = acknowledgedPrayer == next.begins ? .normal : PrayerUrgency(timeUntilNext: remaining)
        switch urgency {
        case .normal:
            style = .normal
        case .soon:
            style = .alert
        case .imminent:
            blinkOn.toggle()
            style = blinkOn ? .alert : .alertDimmed
        }
        return showsCountdown ? .milliseconds(500) : Self.untilNextMinute(after: now)
    }

    private static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func untilNextMinute(after date: Date) -> Duration {
        let next = Calendar.current.nextDate(after: date, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(60)
        return .seconds(next.timeIntervalSince(date) + 0.05)
    }
}
