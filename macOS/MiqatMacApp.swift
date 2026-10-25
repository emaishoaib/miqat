import AppKit
import SwiftUI

@main
struct MiqatMacApp: App {
    @State private var model: TimetableModel
    @State private var status: MenuBarStatus

    init() {
        let model = TimetableModel()
        _model = State(initialValue: model)
        _status = State(initialValue: MenuBarStatus(model: model))
        Task { await model.load() }
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                TimetableScreen(model: model)
                Divider()
                HStack {
                    Spacer()
                    Button("Quit Miqat") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                }
                .padding(10)
            }
            .frame(width: 340, height: 600)
            .onAppear { status.acknowledge() }
        } label: {
            MenuBarLabel(status: status)
        }
        .menuBarExtraStyle(.window)
    }
}
