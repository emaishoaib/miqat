import SwiftUI

@main
struct MiqatApp: App {
    @State private var model = TimetableModel()

    var body: some Scene {
        WindowGroup {
            TimetableScreen(model: model)
                .task { await model.load() }
        }
    }
}
