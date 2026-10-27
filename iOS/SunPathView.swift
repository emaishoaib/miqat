import PrayerKit
import SwiftUI

enum Palette {
    static let day = Color(red: 0x14 / 255, green: 0x38 / 255, blue: 0x6F / 255)
    static let night = Color(red: 0x06 / 255, green: 0x18 / 255, blue: 0x3A / 255)
    static let ink = Color(red: 0xEA / 255, green: 0xF1 / 255, blue: 0xFB / 255)
    static let gold = Color(red: 0xF5 / 255, green: 0xD2 / 255, blue: 0x7A / 255)
    static let dayRed = Color(red: 0xFF / 255, green: 0x9E / 255, blue: 0x8F / 255)
    static let nightRed = Color(red: 0xFF / 255, green: 0x7B / 255, blue: 0x72 / 255)
}

struct SunPathView: View {
    private static let margin: CGFloat = 20
    private static let pulseCycle: TimeInterval = 1.0

    let response: PrayerTimesResponse
    let now: Date
    let refresh: () async -> Void

    @State private var contentWidth: CGFloat = 0
    @State private var launch: Double = 0
    @State private var rippleAt: Date?
    @State private var dayOffset = 0
    @State private var pulseStart: Date?
    @State private var pulseEnd: Date?
    @State private var systemIsDark = Self.systemIsDark()
    @AppStorage(Appearance.key) private var appearance = Appearance.sun

    var body: some View {
        let path = response.sunPath(on: now)
        let next = response.nextPrayer(after: now)
        let today = response.day(containing: now)
        let listed = next.flatMap { response.day(containing: $0.begins) } ?? today
        let shownIndex = listed.flatMap { response.days.firstIndex(of: $0) }.map { min(max($0 + dayOffset, 0), response.days.count - 1) }
        let shown = shownIndex.map { response.days[$0] }

        ScrollView {
            VStack(spacing: 28) {
                Header(date: shown?.date ?? now, source: response.source) {
                    await refreshWithPulse()
                }
                if let path, let next, let today {
                    TimelineView(.animation(paused: pulseStart == nil)) { timeline in
                        KeyframeAnimator(initialValue: 1.0, trigger: rippleAt) { ripple in
                            SunPathDial(day: today, path: path, next: next, now: now, usesDayColours: usesDayColours(on: path), launch: launch, pulse: pulse(at: timeline.date), ripple: ripple, rippleAt: rippleAt)
                        } keyframes: { _ in
                            MoveKeyframe(0)
                            LinearKeyframe(1, duration: 0.9)
                        }
                    }
                    .onAppear {
                        withAnimation(.linear(duration: 1.4)) {
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
        .pullToRefresh {
            await refreshWithPulse()
        }
        .onChange(of: next?.begins) { began, _ in
            if let began, began <= now {
                rippleAt = began
            }
        }
        .onChange(of: listed?.date) {
            dayOffset = 0
        }
        .background {
            (usesDayColours(on: path) ? Palette.day : Palette.night)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: usesDayColours(on: path))
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.ink)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            systemIsDark = Self.systemIsDark()
        }
    }

    private func usesDayColours(on path: SunPath?) -> Bool {
        switch appearance {
        case .sun: isDay(on: path)
        case .system: !systemIsDark
        case .day: true
        case .night: false
        }
    }

    private static func systemIsDark() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.traitCollection.userInterfaceStyle }
            .first == .dark
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

    private func pulse(at date: Date) -> Double {
        guard let pulseStart else { return 0 }
        if let pulseEnd, date >= pulseEnd { return 0 }
        return (date.timeIntervalSince(pulseStart) / Self.pulseCycle).truncatingRemainder(dividingBy: 1)
    }

    private func refreshWithPulse() async {
        startPulse()
        await refresh()
        finishPulse()
    }

    private func startPulse() {
        pulseEnd = nil
        if pulseStart == nil {
            pulseStart = .now
        }
    }

    private func finishPulse() {
        guard let pulseStart else { return }
        let beats = max(1, (Date.now.timeIntervalSince(pulseStart) / Self.pulseCycle).rounded(.up))
        let end = pulseStart.addingTimeInterval(beats * Self.pulseCycle)
        pulseEnd = end
        Task {
            try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))
            if pulseEnd == end {
                self.pulseStart = nil
                pulseEnd = nil
            }
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
    let refresh: () async -> Void

    @State private var explainsTimes = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.title3.bold())
                Text(HijriDate.formatted(date))
                    .foregroundStyle(Palette.ink.opacity(0.7))
                Button {
                    explainsTimes = true
                } label: {
                    HStack(spacing: 6) {
                        SourceLabel(source: source)
                        Image(systemName: "info.circle")
                            .foregroundStyle(Palette.ink.opacity(0.5))
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .sheet(isPresented: $explainsTimes) {
                    TimesExplanationView(source: source)
                }
            }
            Spacer()
            HStack(spacing: 22) {
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Refresh prayer times")
                SettingsButton()
            }
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
    @AnimatableIgnored var usesDayColours: Bool
    var launch: Double
    @AnimatableIgnored var pulse: Double
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

            let sunAngle = path.angle(at: now)
            let sunGrowth = Self.ease(Self.phase(of: launch, from: 0, to: 0.35))
            let arcGrowth = Self.ease(Self.phase(of: launch, from: 0.3, to: 0.85))
            let ringGrowth = Self.overshoot(Self.phase(of: launch, from: 0.82, to: 1))

            if arcGrowth > 0 {
                var remaining = Path()
                remaining.addArc(
                    center: CGPoint(x: Self.center.x * scale, y: Self.center.y * scale),
                    radius: Self.radius * scale,
                    startAngle: .degrees(-sunAngle),
                    endAngle: .degrees(-sunAngle + Self.travel(from: sunAngle, to: path.angle(at: next.begins)) * arcGrowth),
                    clockwise: false
                )
                context.stroke(remaining, with: .color(Palette.gold), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
            }

            var horizon = Path()
            horizon.move(to: CGPoint(x: Self.horizonInset * scale, y: Self.center.y * scale))
            horizon.addLine(to: CGPoint(x: (Self.canvas.width - Self.horizonInset) * scale, y: Self.center.y * scale))
            context.stroke(horizon, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))

            for time in day.times.map({ $0.prayer == next.prayer ? next : $0 }) {
                let dot = circle(around: point(at: path.angle(at: time.begins)), radius: 5, scale: scale)
                context.fill(Path(ellipseIn: dot), with: .color(Palette.ink.opacity(time.begins <= now ? 0.4 : 1)))
            }

            if ringGrowth > 0 {
                context.stroke(
                    Path(ellipseIn: circle(around: point(at: path.angle(at: next.begins)), radius: 10 * ringGrowth, scale: scale)),
                    with: .color(Palette.gold),
                    lineWidth: 2 * scale
                )
            }

            if let rippleAt, ripple < 1 {
                context.stroke(
                    Path(ellipseIn: circle(around: point(at: path.angle(at: rippleAt)), radius: 5 + 21 * ripple, scale: scale)),
                    with: .color(Palette.gold.opacity(0.9 * (1 - ripple))),
                    lineWidth: 2 * scale
                )
            }

            let isDay = now >= path.sunrise && now < path.maghrib
            context.fill(
                Path(ellipseIn: circle(around: point(at: sunAngle), radius: (13 + 3 * (1 - cos(2 * .pi * pulse)) / 2) * sunGrowth, scale: scale)),
                with: .color((isDay ? Palette.gold : Palette.gold.mix(with: Palette.night, by: 0.5, in: .device)).opacity(sunGrowth))
            )

            let x = Self.center.x * scale
            let horizonY = Self.center.y * scale
            let label = context.resolve(Text("Next prayer").font(.caption).foregroundStyle(Palette.ink.opacity(0.7)))
            let name = context.resolve(Text(next.prayer.name).font(.title.weight(.semibold)).foregroundStyle(Palette.ink))
            let isSoon = PrayerUrgency(timeUntilNext: next.begins.timeIntervalSince(now)) != .normal
            let countdownColor = isSoon ? (usesDayColours ? Palette.dayRed : Palette.nightRed) : Palette.gold
            let countdown = context.resolve(Text(Self.countdown(to: next.begins, from: now)).font(.headline).foregroundStyle(countdownColor))
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

    private static func phase(of progress: Double, from start: Double, to end: Double) -> Double {
        min(max((progress - start) / (end - start), 0), 1)
    }

    private static func ease(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }

    private static func overshoot(_ t: Double) -> Double {
        let back = 1.70158
        return t == 0 ? 0 : 1 + (back + 1) * pow(t - 1, 3) + back * pow(t - 1, 2)
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
