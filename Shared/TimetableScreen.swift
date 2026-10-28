import PrayerKit
import SwiftUI

struct TimetableScreen: View {
    let model: TimetableModel

    @Environment(\.openURL) private var openURL
    #if os(macOS)
    @State private var quitBarHeight: CGFloat = 0
    #endif

    var body: some View {
        content
            #if os(macOS)
            .safeAreaInset(edge: .bottom) {
                QuitBar()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        quitBarHeight = height
                    }
            }
            .environment(\.quitBarHeight, quitBarHeight)
            #endif
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let response):
            TimelineView(.everyMinute) { context in
                SunPathView(response: response, now: context.date) {
                    await model.load()
                }
            }
        case .failed(let error):
            ContentUnavailableView {
                Label("Couldn't load prayer times", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                if case CurrentLocationError.denied = error {
                    Button("Open Settings") { openURL(Self.locationSettingsURL) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Try Again") { Task { await model.load() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private static var locationSettingsURL: URL {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices")!
        #else
        URL(string: UIApplication.openSettingsURLString)!
        #endif
    }
}
