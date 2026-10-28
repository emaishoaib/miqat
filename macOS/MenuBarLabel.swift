import AppKit
import PrayerKit
import SwiftUI

@MainActor
enum MenuBarLabel {
    static func image(for status: MenuBarStatus) -> NSImage {
        let size = UserDefaults.standard.string(forKey: MenuBarSize.key).flatMap(MenuBarSize.init) ?? .compact

        if let next = status.next,
           let image = image(
               name: next.prayer.name,
               time: status.detail,
               style: status.style,
               size: size
           ) {
            return image
        }
        let fallback = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Miqat") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    private static func image(name: String, time: String, style: MenuBarStatus.Style, size: MenuBarSize) -> NSImage? {
        let color: Color = switch style {
        case .normal: .black
        case .alert: Color(nsColor: .systemRed)
        case .alertDimmed: Color(nsColor: .systemRed).opacity(0.25)
        }

        let renderer = ImageRenderer(
            content: part(top: name, bottom: time, size: size)
                .foregroundStyle(color)
                .fixedSize()
        )
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = style == .normal
        return image
    }

    @ViewBuilder
    private static func part(top: String, bottom: String, size: MenuBarSize) -> some View {
        switch size {
        case .compact:
            VStack(alignment: .center, spacing: -2.5) {
                Text(top)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(bottom)
                    .font(.system(size: 11.5))
                    .monospacedDigit()
            }
        case .large:
            HStack(spacing: 4) {
                Text(top)
                    .font(.system(size: 13, weight: .semibold))
                Text(bottom)
                    .font(.system(size: 13))
                    .monospacedDigit()
            }
        }
    }
}
