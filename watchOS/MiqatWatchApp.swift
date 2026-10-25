import SwiftUI

@main
struct MiqatWatchApp: App {
    @State private var model = TimetableModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchContentView(model: model)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: Task { await model.load() }
            case .background: WatchDailyRefresh.schedule()
            default: break
            }
        }
        .backgroundTask(.appRefresh) { _ in
            await WatchDailyRefresh.schedule()
            await model.refreshInBackground()
        }
    }
}
