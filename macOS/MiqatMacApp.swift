import SwiftUI

@main
struct MiqatMacApp: App {
    @State private var model: TimetableModel
    @State private var clock = MinuteClock()

    init() {
        let model = TimetableModel()
        _model = State(initialValue: model)
        Task { await model.load() }
    }

    var body: some Scene {
        WindowGroup("Miqat") {
            TimetableScreen(model: model)
                .frame(minWidth: 360, minHeight: 560)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            TimetableScreen(model: model)
                .frame(width: 340, height: 560)
        } label: {
            MenuBarLabel(model: model, clock: clock)
        }
        .menuBarExtraStyle(.window)
    }
}
