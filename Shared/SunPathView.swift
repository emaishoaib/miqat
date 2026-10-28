import PrayerKit
import SwiftUI

struct SunPathView: View {
    private static let margin: CGFloat = 20

    let response: PrayerTimesResponse
    let now: Date
    let refresh: () async -> Void

    @State private var contentWidth: CGFloat = 0
    private static var hasGrownIn = false

    @State private var launch: Double = hasGrownIn ? 1 : 0
    @State private var rippleAt: Date?
    @State private var dayOffset = 0
    @State private var isRefreshing = false
    @State private var systemIsDark = Self.systemIsDark()
    @AppStorage(Appearance.key, store: Appearance.store) private var appearance = Appearance.sun

    var body: some View {
        let path = response.sunPath(on: now)
        let next = response.nextPrayer(after: now)
        let today = response.day(containing: now)
        let listed = next.flatMap { response.day(containing: $0.begins) } ?? today
        let shownIndex = listed.flatMap { response.days.firstIndex(of: $0) }.map { min(max($0 + dayOffset, 0), response.days.count - 1) }
        let shown = shownIndex.map { response.days[$0] }

        ScrollView {
            VStack(spacing: 28) {
                Header(date: shown?.date ?? now, hijriDate: shown?.hijriDate(at: now) ?? now, source: response.source, isRefreshing: isRefreshing) {
                    await refreshShowingProgress()
                }
                if let path, let next, let today {
                    KeyframeAnimator(initialValue: 1.0, trigger: rippleAt) { ripple in
                        SunPathDial(day: today, path: path, next: next, now: now, usesDayColours: usesDayColours(on: path), launch: launch, ripple: ripple, rippleAt: rippleAt)
                    } keyframes: { _ in
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.9)
                    }
                    .onAppear {
                        guard !Self.hasGrownIn else { return }
                        Self.hasGrownIn = true
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
                    #if os(iOS)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30).onEnded { drag in
                            guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                            browse(by: drag.translation.width < 0 ? 1 : -1, from: shownIndex)
                        }
                    )
                    #endif
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
        #if os(iOS)
        .pullToRefresh {
            await refreshShowingProgress()
        }
        #endif
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
        return now >= path.sunrise && now < path.maghrib
    }

    private func browse(by step: Int, from index: Int) {
        guard response.days.indices.contains(index + step) else { return }
        withAnimation {
            dayOffset += step
        }
    }

    private func refreshShowingProgress() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await refresh()
        isRefreshing = false
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
    let hijriDate: Date
    let source: TimesSource
    let isRefreshing: Bool
    let refresh: () async -> Void

    @State private var explanation = TimesExplanation.shared

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.title3.bold())
                Button {
                    explanation.topic = .hijriDate
                    explanation.isShown = true
                } label: {
                    HStack(spacing: 6) {
                        Text(HijriDate.formatted(hijriDate))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                        Image(systemName: "info.circle")
                            .foregroundStyle(Palette.ink.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About the Hijri date")
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
                .padding(.top, 6)
                .sheet(isPresented: $explanation.isShown) {
                    TimesExplanationView(source: source, topic: explanation.topic, hijriDateHasMovedOn: hijriDate != date)
                }
            }
            Spacer()
            HStack(spacing: 22) {
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
