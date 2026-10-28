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
    static let height: CGFloat = 680

    let model: TimetableModel

    @State private var settings = SettingsPage.shared
    @AppStorage(MenuBarDate.showsKey) private var showsDate = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimetableScreen(model: model)
                .frame(width: SunPathView.timetableWidth + (showsDate ? CalendarView.width : 0))
            if settings.isShown {
                SettingsView()
                    .frame(width: SunPathView.timetableWidth)
            }
        }
        .frame(height: Self.height)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
