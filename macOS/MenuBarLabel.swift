import AppKit
import PrayerKit
import SwiftUI

@MainActor
enum MenuBarLabel {
    static func image(for status: MenuBarStatus) -> NSImage {
        let defaults = UserDefaults.standard
        let showsDate = defaults.bool(forKey: MenuBarDate.showsKey)
        let calendar = defaults.string(forKey: MenuBarDate.calendarKey).flatMap(MenuBarDate.init) ?? .gregorian
        let size = defaults.string(forKey: MenuBarSize.key).flatMap(MenuBarSize.init) ?? .compact

        if let next = status.next,
           let image = image(
               name: next.prayer.name,
               time: status.detail,
               style: status.style,
               date: showsDate ? calendar.lines(for: status.today) : nil,
               size: size
           ) {
            return image
        }
        let fallback = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Miqat") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    private static func image(name: String, time: String, style: MenuBarStatus.Style, date: (weekday: String, day: String)?, size: MenuBarSize) -> NSImage? {
        let prayerColor: Color = switch style {
        case .normal: .black
        case .alert: Color(nsColor: .systemRed)
        case .alertDimmed: Color(nsColor: .systemRed).opacity(0.25)
        }
        let dateColor: Color = style == .normal ? .black : menuBarTextColor

        let renderer = ImageRenderer(
            content: HStack(spacing: size == .compact ? 8 : 6) {
                part(top: name, bottom: time, size: size)
                    .foregroundStyle(prayerColor)
                if let date {
                    if size == .large {
                        Text(verbatim: "·")
                            .font(.system(size: 13))
                            .foregroundStyle(dateColor)
                    }
                    part(top: date.weekday, bottom: date.day, size: size)
                        .foregroundStyle(dateColor)
                }
            }
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

    private static var menuBarTextColor: Color {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
    }
}
