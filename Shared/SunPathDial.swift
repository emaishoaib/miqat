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

@Animatable
struct SunPathDial: View {
    static let canvas = CGSize(width: 300, height: 232)
    static let center = CGPoint(x: 150, y: 120)
    static let radius: CGFloat = 95
    static let horizonInset: CGFloat = 18
    static let textGap: CGFloat = 12
    static let compactTextGap: CGFloat = 13

    @AnimatableIgnored var day: PrayerDay
    @AnimatableIgnored var path: SunPath
    @AnimatableIgnored var next: PrayerTime
    @AnimatableIgnored var now: Date
    @AnimatableIgnored var usesDayColours: Bool
    var launch: Double
    @AnimatableIgnored var ripple: Double
    @AnimatableIgnored var rippleAt: Date?
    @AnimatableIgnored var isCompact = false
    @AnimatableIgnored var showsText = true
    @AnimatableIgnored var weight: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.canvas.width

            context.stroke(
                Path(ellipseIn: circle(around: Self.center, radius: Self.radius, scale: scale)),
                with: .color(Palette.ink.opacity(0.5)),
                style: StrokeStyle(lineWidth: 2 * weight * scale, dash: [3 * weight * scale, 6 * weight * scale])
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
                context.stroke(remaining, with: .color(Palette.gold), style: StrokeStyle(lineWidth: 3 * weight * scale, lineCap: .round))
            }

            var horizon = Path()
            horizon.move(to: CGPoint(x: Self.horizonInset * scale, y: Self.center.y * scale))
            horizon.addLine(to: CGPoint(x: (Self.canvas.width - Self.horizonInset) * scale, y: Self.center.y * scale))
            context.stroke(horizon, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 3 * weight * scale, lineCap: .round))

            for time in day.times.map({ $0.prayer == next.prayer ? next : $0 }) {
                let dot = circle(around: point(at: path.angle(at: time.begins)), radius: 5 * weight, scale: scale)
                context.fill(Path(ellipseIn: dot), with: .color(Palette.ink.opacity(time.begins <= now ? 0.4 : 1)))
            }

            if ringGrowth > 0 {
                context.stroke(
                    Path(ellipseIn: circle(around: point(at: path.angle(at: next.begins)), radius: 10 * weight * ringGrowth, scale: scale)),
                    with: .color(Palette.gold),
                    lineWidth: 2 * weight * scale
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
                Path(ellipseIn: circle(around: point(at: sunAngle), radius: 13 * weight * sunGrowth, scale: scale)),
                with: .color((isDay ? Palette.gold : Palette.gold.mix(with: Palette.night, by: 0.5, in: .device)).opacity(sunGrowth))
            )

            guard showsText else { return }

            let x = Self.center.x * scale
            let horizonY = Self.center.y * scale
            let name = context.resolve(Text(next.prayer.name).font(isCompact ? .system(size: 32 * scale, weight: .semibold) : .title.weight(.semibold)).foregroundStyle(Palette.ink))
            let countdownColor = Self.countdownColor(to: next.begins, from: now, usesDayColours: usesDayColours)
            let countdown = context.resolve(Text(Self.countdown(to: next.begins, from: now)).font(isCompact ? .system(size: 28 * scale, weight: .semibold) : .headline).foregroundStyle(countdownColor))
            let gap = isCompact ? Self.compactTextGap * scale : Self.textGap
            context.draw(name, at: CGPoint(x: x, y: horizonY - gap), anchor: .bottom)
            context.draw(countdown, at: CGPoint(x: x, y: horizonY + gap), anchor: .top)

            if !isCompact {
                let label = context.resolve(Text(next.prayer == .sunrise ? "Fajr until" : "Next prayer").font(.caption).foregroundStyle(Palette.ink.opacity(0.7)))
                let time = context.resolve(Text("at \(next.begins.formatted(date: .omitted, time: .shortened))").font(.subheadline).foregroundStyle(Palette.ink.opacity(0.7)))
                context.draw(label, at: CGPoint(x: x, y: horizonY - gap - name.measure(in: size).height), anchor: .bottom)
                context.draw(time, at: CGPoint(x: x, y: horizonY + gap + countdown.measure(in: size).height), anchor: .top)
            }
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

    static func countdown(to date: Date, from now: Date) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        return minutes >= 60 ? "in \(minutes / 60)h \(minutes % 60)m" : "in \(minutes)m"
    }

    static func countdownColor(to date: Date, from now: Date, usesDayColours: Bool) -> Color {
        guard PrayerUrgency(timeUntilNext: date.timeIntervalSince(now)) != .normal else { return Palette.gold }
        return usesDayColours ? Palette.dayRed : Palette.nightRed
    }
}
