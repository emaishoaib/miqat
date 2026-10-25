import SwiftUI

@main
struct MiqatWatchApp: App {
    @State private var model = TimetableModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView(model: model)
                .task { await model.load() }
        }
    }
}
