import PrayerKit
import SwiftUI

struct ContentView: View {
    @State private var model = TimetableModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case .loaded(let response):
                TimelineView(.everyMinute) { context in
                    TimetableView(response: response, now: context.date)
                }
            case .failed(let error):
                ContentUnavailableView {
                    Label("Couldn't load prayer times", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    if case CurrentLocationError.denied = error {
                        Button("Open Settings") {
                            openURL(URL(string: UIApplication.openSettingsURLString)!)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Try Again") {
                            Task { await model.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task { await model.load() }
    }
}

#Preview {
    ContentView()
}
