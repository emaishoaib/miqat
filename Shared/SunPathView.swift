import PrayerKit
import SwiftUI

struct SunPathView: View {
    private static let margin: CGFloat = 20
    private static let longestDragStep: TimeInterval = 6 * 60 * 60
    private static let magnetReach: Double = 10

    let response: PrayerTimesResponse
    let now: Date
    let refresh: () async -> Void

    @State private var contentWidth: CGFloat = 0
    private static var hasGrownIn = false

    @State private var launch: Double = hasGrownIn ? 1 : 0
    @State private var rippleAt: Date?
    @State private var draggedTime: Date?
    @State private var spin: SunSpin?
    @State private var isRefreshing = false
    @State private var systemIsDark = Self.systemIsDark()
    @AppStorage(Appearance.key, store: Appearance.store) private var appearance = Appearance.sun
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shownTime: Date {
        draggedTime ?? now
    }

    var body: some View {
        let path = response.sunPath(on: shownTime)
        let next = response.nextPrayer(after: shownTime)
        let today = response.day(containing: shownTime)
        let shown = next.flatMap { response.day(containing: $0.begins) } ?? today

        ScrollView {
            VStack(spacing: 28) {
                Header(date: shown?.date ?? shownTime, hijriDate: shown?.hijriDate(at: shownTime) ?? shownTime, source: shown?.source ?? response.source, nearbyMosque: response.nearbyMosque, isRefreshing: isRefreshing) {
                    await refreshShowingProgress()
                }
                if let path, let next, let today {
                    KeyframeAnimator(initialValue: 1.0, trigger: rippleAt) { ripple in
                        SunPathDial(day: today, path: path, next: next, now: shownTime, usesDayColours: usesDayColours(on: path), launch: launch, ripple: ripple, rippleAt: rippleAt, countdownVisibility: draggedTime == nil ? 1 : 0, dragProgress: draggedTime == nil ? 0 : 1)
                            .animation(.easeInOut(duration: 0.3), value: draggedTime == nil)
                    } keyframes: { _ in
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.9)
                    }
                    .overlay {
                        SunHandle(angle: path.angle(at: shownTime), day: shown?.date ?? shownTime, onDrag: drag(toAngle:), onRelease: spinBack, onStep: step(byDays:))
                    }
                    .onAppear {
                        guard !Self.hasGrownIn else { return }
                        Self.hasGrownIn = true
                        withAnimation(.linear(duration: 1.4)) {
                            launch = 1
                        }
                    }
                }
                if let shown {
                    PrayerList(day: shown, next: next, now: shownTime)
                        .padding(.horizontal, contentWidth * SunPathDial.horizonInset / SunPathDial.canvas.width)
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
        #if os(macOS)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            (geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom).rounded(.up)
        } action: { _, height in
            PopUpHeight.shared.fittingContent = height
        }
        #endif
        #if os(iOS)
        .pullToRefresh {
            await refreshShowingProgress()
        }
        #endif
        .onChange(of: response.nextPrayer(after: now)?.begins) { began, _ in
            if let began, began <= now {
                rippleAt = began
            }
        }
        .background {
            if let spin {
                TimelineView(.animation) { frame in
                    Color.clear.onChange(of: frame.date) {
                        draggedTime = spin.time(at: frame.date, returningTo: now)
                        if draggedTime == nil {
                            self.spin = nil
                        }
                    }
                }
            }
        }
        .background {
            (usesDayColours(on: path) ? Palette.day : Palette.night)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: usesDayColours(on: path))
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.ink)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: Self.becameActive)) { _ in
            systemIsDark = Self.systemIsDark()
        }
    }

    private func usesDayColours(on path: SunPath?) -> Bool {
        appearance.usesDayColours(sunIsUp: isDay(on: path), systemIsDark: systemIsDark)
    }

    #if os(iOS)
    private static let becameActive = UIApplication.didBecomeActiveNotification

    private static func systemIsDark() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.traitCollection.userInterfaceStyle }
            .first == .dark
    }
    #else
    private static let becameActive = NSApplication.didBecomeActiveNotification

    private static func systemIsDark() -> Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    #endif

    private func isDay(on path: SunPath?) -> Bool {
        guard let path else { return true }
        return shownTime >= path.sunrise && shownTime < path.maghrib
    }

    private func drag(toAngle angle: Double) {
        guard let path = response.sunPath(on: shownTime) else { return }
        let time = response.closestCoveredTime(to: path.date(at: magnetised(angle, on: path), closestTo: shownTime))
        guard abs(time.timeIntervalSince(shownTime)) < Self.longestDragStep else { return }
        spin = nil
        draggedTime = time
    }

    private func magnetised(_ angle: Double, on path: SunPath) -> Double {
        let offsets = (response.day(containing: shownTime)?.times ?? [])
            .filter { abs(path.date(at: path.angle(at: $0.begins), closestTo: shownTime).timeIntervalSince($0.begins)) < 1 }
            .map { SunPathDial.wrapped(angle - path.angle(at: $0.begins)) }
        guard let offset = offsets.min(by: { abs($0) < abs($1) }), abs(offset) < Self.magnetReach else { return angle }
        return SunPathDial.wrapped(angle - offset + offset * pow(abs(offset) / Self.magnetReach, 2))
    }

    private func spinBack() {
        guard let draggedTime, !reduceMotion else {
            draggedTime = nil
            return
        }
        spin = SunSpin(from: SunSpin.start(from: draggedTime, returningTo: now), begins: .now)
    }

    private func step(byDays days: Int) {
        guard let time = Calendar.current.date(byAdding: .day, value: days, to: shownTime) else { return }
        spin = nil
        draggedTime = Calendar.current.isDate(time, inSameDayAs: now) ? nil : response.closestCoveredTime(to: time)
    }

    private func refreshShowingProgress() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await refresh()
        isRefreshing = false
    }
}

private struct SunSpin {
    private static let secondsPerLoop: TimeInterval = 0.7
    private static let shortest: TimeInterval = 0.4
    private static let day: TimeInterval = 24 * 60 * 60

    let from: Date
    let begins: Date

    static func start(from dragged: Date, returningTo now: Date) -> Date {
        let days = Calendar.current.dateComponents([.day], from: dragged, to: now).day ?? 0
        guard abs(days) > 1 else { return dragged }
        return Calendar.current.date(byAdding: .day, value: days - days.signum(), to: dragged) ?? dragged
    }

    func time(at frame: Date, returningTo now: Date) -> Date? {
        let distance = now.timeIntervalSince(from)
        let duration = max(abs(distance) / Self.day * Self.secondsPerLoop, Self.shortest)
        let progress = max(frame.timeIntervalSince(begins) / duration, 0)
        guard progress < 1 else { return nil }
        return from.addingTimeInterval(distance * UnitCurve.easeInOut.value(at: progress))
    }
}

private struct SunHandle: View {
    private static let size: CGFloat = 56
    private static let space = "dial"

    let angle: Double
    let day: Date
    let onDrag: (Double) -> Void
    let onRelease: () -> Void
    let onStep: (Int) -> Void

    @State private var grabOffset: Double?

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / SunPathDial.canvas.width
            let sun = SunPathDial.point(at: angle)

            Circle()
                .fill(.clear)
                .contentShape(Circle())
                .frame(width: Self.size, height: Self.size)
                .accessibilityElement()
                .accessibilityLabel("Sun")
                .accessibilityValue(day.formatted(date: .complete, time: .omitted))
                .accessibilityHint("Swipe up or down to move between days")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: onStep(1)
                    case .decrement: onStep(-1)
                    @unknown default: break
                    }
                }
                .position(x: sun.x * scale, y: sun.y * scale)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                        .onChanged { drag in
                            let finger = SunPathDial.angle(of: drag.location, scale: scale)
                            let offset = grabOffset ?? angle - finger
                            grabOffset = offset
                            onDrag(SunPathDial.wrapped(finger + offset))
                        }
                        .onEnded { _ in
                            grabOffset = nil
                            onRelease()
                        }
                )
        }
        .coordinateSpace(.named(Self.space))
    }
}

private struct Header: View {
    let date: Date
    let hijriDate: Date
    let source: TimesSource
    let nearbyMosque: NearbyMosque?
    let isRefreshing: Bool
    let refresh: () async -> Void

    @State private var explanation = TimesExplanation.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            dateAndButtons
            sourceRow
        }
    }

    private var dateAndButtons: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(date.formatted(Self.shortDate))
                        .font(.title3.bold())
                        .fixedSize()
                    if Calendar.current.isDateInToday(date) {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink.opacity(0.5))
                            .fixedSize()
                    }
                }
                Button {
                    explanation.topic = .hijriDate
                    explanation.isShown = true
                } label: {
                    HStack(spacing: 6) {
                        Text(HijriDate.formatted(hijriDate))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About the Hijri date")
            }
            .layoutPriority(1)
            Spacer()
            HStack(spacing: 22) {
                #if os(macOS)
                if let mosqueToCheck = source.mosqueToCheck(nearby: nearbyMosque) {
                    Button {
                        openURL(mosqueToCheck.websiteMarkedWithPlace)
                    } label: {
                        Image(systemName: "globe")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("Check \(mosqueToCheck.name)")
                    .accessibilityLabel("Open the website of \(mosqueToCheck.name)")
                }
                #endif
                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    Group {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh prayer times")
                SettingsButton()
            }
            .font(.title3)
        }
    }

    private var sourceRow: some View {
        Button {
            explanation.topic = .times
            explanation.isShown = true
        } label: {
            HStack(spacing: 6) {
                SourceLabel(source: source)
                Image(systemName: "info.circle")
                    .foregroundStyle(Palette.ink.opacity(0.5))
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $explanation.isShown) {
            TimesExplanationView(source: source, topic: explanation.topic, hijriDateHasMovedOn: hijriDate != date)
        }
        .padding(.top, 6)
    }

    private static var shortDate: Date.VerbatimFormatStyle {
        Date.VerbatimFormatStyle(format: "\(weekday: .abbreviated), \(day: .defaultDigits) \(month: .abbreviated)", locale: .current, timeZone: .current, calendar: .current)
    }
}

private struct PrayerList: View {
    static let columnWidth: CGFloat = 84

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
