import PrayerKit
import SwiftUI

struct WatchContentView: View {
    let model: TimetableModel

    @State private var clock = MinuteClock()

    var body: some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .loaded(let response):
            WatchTimetableView(response: response, now: clock.now, isRefreshing: model.isRefreshing) {
                await model.load()
            }
        case .failed(let error):
            ContentUnavailableView {
                Label("No prayer times", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
            }
        }
    }
}
