import AppKit
import PrayerKit
import SwiftUI

struct MenuBarLabel: View {
    let model: TimetableModel
    let clock: MinuteClock

    var body: some View {
        if case .loaded(let response) = model.state,
           let next = response.nextPrayer(after: clock.now),
           let image = Self.image(name: next.prayer.name, time: next.begins.formatted(date: .omitted, time: .shortened)) {
            Image(nsImage: image)
        } else {
            Image(systemName: "moon.stars")
        }
    }

    private static func image(name: String, time: String) -> NSImage? {
        let renderer = ImageRenderer(
            content: VStack(alignment: .center, spacing: -2) {
                Text(name)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(time)
                    .font(.system(size: 10.5))
                    .monospacedDigit()
            }
            .foregroundStyle(.black)
            .fixedSize()
        )
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}
