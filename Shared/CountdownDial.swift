import SwiftUI

struct CountdownDial: View {
    let target: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, target.timeIntervalSince(context.date))
            ZStack {
                DialTicks()
                Sector(start: .degrees(-90), end: .degrees(-90 + min(remaining, 3600) / 3600 * 360))
                    .fill(Color.accentColor.opacity(0.3))
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                Text(verbatim: Self.label(remaining))
                    .font(.headline)
                    .monospacedDigit()
            }
            .frame(width: 88, height: 88)
        }
    }

    private static func label(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds >= 3600 {
            return "\(seconds / 3600)h \(seconds % 3600 / 60)m"
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct DialTicks: View {
    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            ForEach(0..<12) { tick in
                Capsule()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: tick % 3 == 0 ? 2 : 1, height: tick % 3 == 0 ? 7 : 4)
                    .offset(y: -radius + 6)
                    .rotationEffect(.degrees(Double(tick) * 30))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }
}

private struct Sector: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}
