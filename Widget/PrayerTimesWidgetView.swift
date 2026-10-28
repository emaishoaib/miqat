import PrayerKit
import SwiftUI
import WidgetKit

struct PrayerTimesWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Appearance.key, store: Appearance.store) private var appearance = Appearance.sun

    let entry: PrayerEntry

    var body: some View {
        let now = entry.date
        let path = entry.response?.sunPath(on: now)
        let sunIsUp = path.map { now >= $0.sunrise && now < $0.maghrib } ?? true
        let isDay = appearance.usesDayColours(sunIsUp: sunIsUp, systemIsDark: colorScheme == .dark)

        Group {
            if let response = entry.response,
               let path,
               let next = response.nextPrayer(after: now),
               let today = response.day(containing: now) {
                let listed = response.day(containing: next.begins) ?? today
                ZStack(alignment: .top) {
                    VStack(spacing: 2) {
                        Spacer(minLength: 0)
                        SunPathDial(day: today, path: path, next: next, now: now, usesDayColours: isDay, launch: 1, ripple: 1, rippleAt: nil, isCompact: true)
                            .frame(width: 118)
                        PrayerGrid(day: listed, next: next, now: now)
                    }
                    HijriDateCorners(date: listed.date)
                }
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, 8)
            } else {
                Text("Open Miqat to load prayer times")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .foregroundStyle(Palette.ink)
        .containerBackground(for: .widget) {
            isDay ? Palette.day : Palette.night
        }
    }
}

private struct HijriDateCorners: View {
    let date: Date

    var body: some View {
        HStack(alignment: .top) {
            Text(HijriDate.day(date))
                .font(.system(size: 24, weight: .semibold))
                .alignmentGuide(.top) { $0[.firstTextBaseline] - Self.capHeight(size: 24, weight: .semibold) }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(HijriDate.shortMonth(date))
                    .opacity(0.75)
                Text(String(HijriDate.year(date)))
                    .opacity(0.5)
            }
            .font(.system(size: 11))
            .alignmentGuide(.top) { $0[.firstTextBaseline] - Self.capHeight(size: 11, weight: .regular) }
        }
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static func capHeight(size: CGFloat, weight: UIFont.Weight) -> CGFloat {
        UIFont.systemFont(ofSize: size, weight: weight).capHeight
    }
}

private struct PrayerGrid: View {
    let day: PrayerDay
    let next: PrayerTime
    let now: Date

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 1) {
            ForEach(day.times, id: \.prayer) { time in
                let isNext = time == next
                VStack(spacing: 0) {
                    Text(time.prayer.name)
                    Text(time.begins.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: isNext ? .semibold : .regular))
                .foregroundStyle(isNext ? Palette.gold : Palette.ink)
                .opacity(time.begins <= now && !isNext ? 0.45 : 1)
                .lineLimit(1)
            }
        }
    }
}
