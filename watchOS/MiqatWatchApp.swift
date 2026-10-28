import SwiftUI

@main
struct MiqatWatchApp: App {
    @State private var model = WatchTimetableModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchContentView(model: model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        .backgroundTask(.watchConnectivity) {
            await model.receivePendingContent()
        }
    }
}
