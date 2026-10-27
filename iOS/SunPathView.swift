import PrayerKit
import SwiftUI

enum Palette {
    static let day = Color(red: 0x14 / 255, green: 0x38 / 255, blue: 0x6F / 255)
    static let night = Color(red: 0x06 / 255, green: 0x18 / 255, blue: 0x3A / 255)
    static let ink = Color(red: 0xEA / 255, green: 0xF1 / 255, blue: 0xFB / 255)
    static let gold = Color(red: 0xF5 / 255, green: 0xD2 / 255, blue: 0x7A / 255)
}

struct SunPathView: View {
    private static let margin: CGFloat = 20

    let response: PrayerTimesResponse
    let now: Date
    let isRefreshing: Bool
    let refresh: () async -> Void

    @State private var contentWidth: CGFloat = 0
    @State private var launch: Double = 0
    @State private var rippleAt: Date?
    @State private var dayOffset = 0

    var body: some View {
        let path = response.sunPath(on: now)
        let next = response.nextPrayer(after: now)
        let today = response.day(containing: now)
        let listed = next.flatMap { response.day(containing: $0.begins) } ?? today
        let shownIndex = listed.flatMap { response.days.firstIndex(of: $0) }.map { min(max($0 + dayOffset, 0), response.days.count - 1) }
        let shown = shownIndex.map { response.days[$0] }

        ScrollView {
            VStack(spacing: 28) {
                Header(date: shown?.date ?? now, source: response.source, isRefreshing: isRefreshing)
                if let path, let next, let today {
                    KeyframeAnimator(initialValue: 1.0, trigger: rippleAt) { ripple in
                        SunPathDial(day: today, path: path, next: next, now: now, launch: launch, ripple: ripple, rippleAt: rippleAt)
                    } keyframes: { _ in
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.9)
                    }
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.3)) {
                            launch = 1
                        }
                    }
                }
                if let shown, let shownIndex {
                    let gap = contentWidth * SunPathDial.horizonInset / SunPathDial.canvas.width + Self.margin
                    HStack(spacing: 0) {
                        DayChevron(systemName: "chevron.left", label: "Previous day", isShown: shownIndex > 0, width: gap) {
                            browse(by: -1, from: shownIndex)
                        }
                        PrayerList(day: shown, next: next, now: now)
                        DayChevron(systemName: "chevron.right", label: "Next day", isShown: shownIndex < response.days.count - 1, width: gap) {
                            browse(by: 1, from: shownIndex)
                        }
                    }
                    .padding(.horizontal, -Self.margin)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30).onEnded { drag in
                            guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                            browse(by: drag.translation.width < 0 ? 1 : -1, from: shownIndex)
                        }
                    )
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                contentWidth = width
            }
            .padding(.horizontal, Self.margin)
            .padding(.vertical, 12)
        }
        .pullToRefresh { await refresh() }
        .onChange(of: next?.begins) { began, _ in
            if let began, began <= now {
                rippleAt = began
            }
        }
        .onChange(of: listed?.date) {
            dayOffset = 0
        }
        .background {
            (isDay(on: path) ? Palette.day : Palette.night)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: isDay(on: path))
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.ink)
        .preferredColorScheme(.dark)
    }

    private func isDay(on path: SunPath?) -> Bool {
        guard let path else { return true }
        return now >= path.sunrise && now < path.maghrib
    }

    private func browse(by step: Int, from index: Int) {
        guard response.days.indices.contains(index + step) else { return }
        withAnimation {
            dayOffset += step
        }
    }
}

private struct DayChevron: View {
    let systemName: String
    let label: String
    let isShown: Bool
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink.opacity(0.45))
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isShown ? 1 : 0)
        .disabled(!isShown)
        .accessibilityLabel(label)
    }
}

private struct Header: View {
    let date: Date
    let source: TimesSource
    let isRefreshing: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.title3.bold())
                Text(HijriDate.formatted(date))
                    .foregroundStyle(Palette.ink.opacity(0.7))
                SourceLabel(source: source)
                    .font(.subheadline)
                    .padding(.top, 6)
            }
            Spacer()
            if isRefreshing {
                ProgressView()
                    .padding(.trailing, 8)
            }
            SettingsButton()
                .font(.title3)
        }
    }
}

@Animatable
private struct SunPathDial: View {
    static let canvas = CGSize(width: 300, height: 232)
    static let center = CGPoint(x: 150, y: 120)
    static let radius: CGFloat = 95
    static let horizonInset: CGFloat = 18
    static let textGap: CGFloat = 12

    @AnimatableIgnored var day: PrayerDay
    @AnimatableIgnored var path: SunPath
    @AnimatableIgnored var next: PrayerTime
    @AnimatableIgnored var now: Date
    var launch: Double
    @AnimatableIgnored var ripple: Double
    @AnimatableIgnored var rippleAt: Date?

    var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.canvas.width

            context.stroke(
                Path(ellipseIn: circle(around: Self.center, radius: Self.radius, scale: scale)),
                with: .color(Palette.ink.opacity(0.5)),
                style: StrokeStyle(lineWidth: 2 * scale, dash: [3 * scale, 6 * scale])
            )

            let sunAngle = 180 - Self.travel(from: 180, to: path.angle(at: now)) * launch
            var remaining = Path()
            remaining.addArc(
                center: CGPoint(x: Self.center.x * scale, y: Self.center.y * scale),
                radius: Self.radius * scale,
                startAngle: .degrees(-sunAngle),
                endAngle: .degrees(-sunAngle + Self.travel(from: sunAngle, to: path.angle(at: next.begins))),
                clockwise: false
            )
            context.stroke(remaining, with: .color(Palette.gold), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))

            var horizon = Path()
            horizon.move(to: CGPoint(x: Self.horizonInset * scale, y: Self.center.y * scale))
            horizon.addLine(to: CGPoint(x: (Self.canvas.width - Self.horizonInset) * scale, y: Self.center.y * scale))
            context.stroke(horizon, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))

            for time in day.times.map({ $0.prayer == next.prayer ? next : $0 }) {
                let dot = circle(around: point(at: path.angle(at: time.begins)), radius: 5, scale: scale)
                context.fill(Path(ellipseIn: dot), with: .color(Palette.ink.opacity(time.begins <= now ? 0.4 : 1)))
            }

            context.stroke(
                Path(ellipseIn: circle(around: point(at: path.angle(at: next.begins)), radius: 10, scale: scale)),
                with: .color(Palette.gold),
                lineWidth: 2 * scale
            )

            if let rippleAt, ripple < 1 {
                context.stroke(
                    Path(ellipseIn: circle(around: point(at: path.angle(at: rippleAt)), radius: 5 + 21 * ripple, scale: scale)),
                    with: .color(Palette.gold.opacity(0.9 * (1 - ripple))),
                    lineWidth: 2 * scale
                )
            }

            let isDay = now >= path.sunrise && now < path.maghrib
            context.fill(
                Path(ellipseIn: circle(around: point(at: sunAngle), radius: 13, scale: scale)),
                with: .color(isDay ? Palette.gold : Palette.gold.mix(with: Palette.night, by: 0.5, in: .device))
            )

            let x = Self.center.x * scale
            let horizonY = Self.center.y * scale
            let label = context.resolve(Text("Next prayer").font(.caption).foregroundStyle(Palette.ink.opacity(0.7)))
            let name = context.resolve(Text(next.prayer.name).font(.title.weight(.semibold)).foregroundStyle(Palette.ink))
            let countdown = context.resolve(Text(Self.countdown(to: next.begins, from: now)).font(.headline).foregroundStyle(Palette.gold))
            let time = context.resolve(Text("at \(next.begins.formatted(date: .omitted, time: .shortened))").font(.subheadline).foregroundStyle(Palette.ink.opacity(0.7)))
            let nameHeight = name.measure(in: size).height
            let countdownHeight = countdown.measure(in: size).height
            context.draw(name, at: CGPoint(x: x, y: horizonY - Self.textGap), anchor: .bottom)
            context.draw(label, at: CGPoint(x: x, y: horizonY - Self.textGap - nameHeight), anchor: .bottom)
            context.draw(countdown, at: CGPoint(x: x, y: horizonY + Self.textGap), anchor: .top)
            context.draw(time, at: CGPoint(x: x, y: horizonY + Self.textGap + countdownHeight), anchor: .top)
        }
        .aspectRatio(Self.canvas, contentMode: .fit)
    }

    private func point(at angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: Self.center.x + Self.radius * cos(radians), y: Self.center.y - Self.radius * sin(radians))
    }

    private static func travel(from start: Double, to end: Double) -> Double {
        let degrees = (start - end).truncatingRemainder(dividingBy: 360)
        return degrees < 0 ? degrees + 360 : degrees
    }

    private func circle(around center: CGPoint, radius: CGFloat, scale: CGFloat) -> CGRect {
        CGRect(x: (center.x - radius) * scale, y: (center.y - radius) * scale, width: 2 * radius * scale, height: 2 * radius * scale)
    }

    private static func countdown(to date: Date, from now: Date) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        return minutes >= 60 ? "in \(minutes / 60)h \(minutes % 60)m" : "in \(minutes)m"
    }
}

private struct PrayerList: View {
    static let columnWidth: CGFloat = 76

    let day: PrayerDay
    let next: PrayerTime?
    let now: Date

    var body: some View {
        let showsJamaat = day.times.contains { $0.jamaat != nil }

        VStack(spacing: 0) {
            HStack {
                Text("Prayer")
                Spacer()
                Text("Begins")
                    .frame(width: Self.columnWidth, alignment: .trailing)
                if showsJamaat {
                    Text("Jamaat")
                        .frame(width: Self.columnWidth, alignment: .trailing)
                }
            }
            .font(.footnote)
            .foregroundStyle(Palette.ink.opacity(0.6))
            .padding(.bottom, 8)

            ForEach(day.times, id: \.prayer) { time in
                Rectangle()
                    .fill(Palette.ink.opacity(0.15))
                    .frame(height: 0.5)
                PrayerRow(time: time, isNext: time == next, hasPassed: time.begins <= now, showsJamaat: showsJamaat)
            }
        }
    }
}

private struct PrayerRow: View {
    let time: PrayerTime
    let isNext: Bool
    let hasPassed: Bool
    let showsJamaat: Bool

    var body: some View {
        HStack {
            Text(time.prayer.name)
            Spacer()
            Text(time.begins.formatted(date: .omitted, time: .shortened))
                .frame(width: PrayerList.columnWidth, alignment: .trailing)
            if showsJamaat {
                Text(time.jamaat?.formatted(date: .omitted, time: .shortened) ?? "")
                    .frame(width: PrayerList.columnWidth, alignment: .trailing)
            }
        }
        .monospacedDigit()
        .fontWeight(isNext ? .semibold : .regular)
        .foregroundStyle(isNext ? Palette.gold : Palette.ink)
        .opacity(hasPassed && !isNext ? 0.45 : 1)
        .padding(.vertical, 10)
    }
}
