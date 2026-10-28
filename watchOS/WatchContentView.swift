import PrayerKit
import SwiftUI

struct WatchContentView: View {
    let model: WatchTimetableModel

    @State private var clock = MinuteClock()

    var body: some View {
        if let response = model.response {
            WatchTimetableView(response: response, now: clock.now, isRefreshing: model.isRefreshing) {
                await model.refresh()
            }
        } else if model.isRefreshing {
            ProgressView()
        } else {
            ContentUnavailableView {
                Label("No prayer times", systemImage: "iphone")
            } description: {
                Text("Open Miqat on your iPhone.")
            } actions: {
                Button("Try Again") { Task { await model.refresh() } }
            }
        }
    }
}
