import PrayerKit
import SwiftUI

struct ContentView: View {
    @State private var model = TimetableModel()

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case .loaded(let response):
                TimelineView(.everyMinute) { context in
                    TimetableView(response: response, now: context.date)
                }
            case .failed(let message):
                ContentUnavailableView(
                    "Couldn't load prayer times",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .task { await model.load() }
    }
}

#Preview {
    ContentView()
}
