import AppKit
import PrayerKit
import SwiftUI

struct MenuBarLabel: View {
    let status: MenuBarStatus

    var body: some View {
        if let next = status.next,
           let image = Self.image(
               name: next.prayer.name,
               time: next.begins.formatted(date: .omitted, time: .shortened),
               style: status.style
           ) {
            Image(nsImage: image)
        } else {
            Image(systemName: "moon.stars")
        }
    }

    private static func image(name: String, time: String, style: MenuBarStatus.Style) -> NSImage? {
        let color: Color = switch style {
        case .normal: .black
        case .alert: Color(nsColor: .systemRed)
        case .alertDimmed: Color(nsColor: .systemRed).opacity(0.25)
        }

        let renderer = ImageRenderer(
            content: VStack(alignment: .center, spacing: -2) {
                Text(name)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(time)
                    .font(.system(size: 10.5))
                    .monospacedDigit()
            }
            .foregroundStyle(color)
            .fixedSize()
        )
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = style == .normal
        return image
    }
}
