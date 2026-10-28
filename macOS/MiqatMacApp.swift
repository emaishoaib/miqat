import AppKit
import SwiftUI

@main
struct MiqatMacApp: App {
    @State private var model: TimetableModel
    @State private var status: MenuBarStatus
    @State private var settings = SettingsPage.shared

    init() {
        let model = TimetableModel()
        _model = State(initialValue: model)
        _status = State(initialValue: MenuBarStatus(model: model))
        Task { await model.load() }
    }

    var body: some Scene {
        MenuBarExtra {
            ZStack {
                TimetableScreen(model: model)
                if settings.isShown {
                    SettingsView()
                }
            }
            .frame(width: 360, height: 680)
            .onAppear {
                status.acknowledge()
                settings.isShown = false
            }
        } label: {
            MenuBarLabel(status: status)
        }
        .menuBarExtraStyle(.window)
    }
}
