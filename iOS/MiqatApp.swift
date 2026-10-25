import SwiftUI

@main
struct MiqatApp: App {
    @State private var model = TimetableModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TimetableScreen(model: model)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: Task { await model.load() }
            case .background: DailyRefresh.schedule()
            default: break
            }
        }
        .backgroundTask(.appRefresh(DailyRefresh.identifier)) {
            await DailyRefresh.schedule()
            await model.refreshInBackground()
        }
    }
}
