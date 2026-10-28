import AppKit
import PrayerKit
import SwiftUI

struct MenuBarLabel: View {
    let status: MenuBarStatus

    @AppStorage(MenuBarDate.showsKey) private var showsDate = false
    @AppStorage(MenuBarDate.calendarKey) private var calendar = MenuBarDate.gregorian

    var body: some View {
        if let next = status.next,
           let image = Self.image(
               name: next.prayer.name,
               time: status.detail,
               style: status.style,
               date: showsDate ? calendar.lines(for: status.today) : nil
           ) {
            Image(nsImage: image)
        } else {
            Image(systemName: "moon.stars")
        }
    }

    private static func image(name: String, time: String, style: MenuBarStatus.Style, date: (weekday: String, day: String)?) -> NSImage? {
        let prayerColor: Color = switch style {
        case .normal: .black
        case .alert: Color(nsColor: .systemRed)
        case .alertDimmed: Color(nsColor: .systemRed).opacity(0.25)
        }
        let dateColor: Color = style == .normal ? .black : menuBarTextColor

        let renderer = ImageRenderer(
            content: HStack(spacing: 8) {
                lines(top: name, bottom: time)
                    .foregroundStyle(prayerColor)
                if let date {
                    lines(top: date.weekday, bottom: date.day)
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

    private static func lines(top: String, bottom: String) -> some View {
        VStack(alignment: .center, spacing: -2.5) {
            Text(top)
                .font(.system(size: 11.5, weight: .semibold))
            Text(bottom)
                .font(.system(size: 11.5))
                .monospacedDigit()
        }
    }

    private static var menuBarTextColor: Color {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
    }
}
