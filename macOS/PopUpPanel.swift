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
    static let width: CGFloat = 360
    static let height: CGFloat = 680

    let model: TimetableModel
    var onOpenURL: () -> Void = {}

    @State private var settings = SettingsPage.shared

    var body: some View {
        ZStack {
            TimetableScreen(model: model)
            if settings.isShown {
                SettingsView()
            }
        }
        .frame(width: Self.width, height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.openURL, OpenURLAction { _ in
            onOpenURL()
            return .systemAction
        })
    }
}
