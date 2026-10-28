import AppKit
import SwiftUI

final class PopUpPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

struct PopUpContent: View {
    let model: TimetableModel

    @State private var settings = SettingsPage.shared
    @AppStorage(MenuBarDate.showsKey) private var showsDate = false

    var body: some View {
        ZStack {
            TimetableScreen(model: model)
            if settings.isShown {
                SettingsView()
            }
        }
        .frame(width: showsDate ? 360 + CalendarView.width : 360, height: 680)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
