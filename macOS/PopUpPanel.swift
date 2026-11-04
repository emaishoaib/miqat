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

@MainActor
@Observable
final class PopUpHeight {
    static let shared = PopUpHeight()

    var fittingContent = PopUpContent.defaultHeight
}

struct PopUpContent: View {
    static let width: CGFloat = 360
    static let defaultHeight: CGFloat = 680

    let model: TimetableModel
    var onOpenURL: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}

    @State private var settings = SettingsPage.shared

    var body: some View {
        ZStack {
            TimetableScreen(model: model)
            if settings.isShown {
                SettingsView(onCheckForUpdates: onCheckForUpdates)
            }
        }
        .frame(width: Self.width)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.openURL, OpenURLAction { _ in
            onOpenURL()
            return .systemAction
        })
    }
}
