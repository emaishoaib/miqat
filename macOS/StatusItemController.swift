import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private static let gap: CGFloat = 6
    private static let screenMargin: CGFloat = 8

    private let model = TimetableModel()
    private let status: MenuBarStatus
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let content: NSHostingController<PopUpContent>
    private let panel = PopUpPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private var clickMonitor: Any?

    override init() {
        status = MenuBarStatus(model: model)
        content = NSHostingController(rootView: PopUpContent(model: model))
        content.sizingOptions = [.preferredContentSize]
        super.init()

        panel.contentViewController = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.onCancel = { [weak self] in
            self?.dismiss()
        }

        if #available(macOS 27, *) {
            statusItem.expandedInterfaceDelegate = self
        } else {
            statusItem.button?.target = self
            statusItem.button?.action = #selector(toggle)
        }
        updateImage()
        observeStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(updateImage), name: UserDefaults.didChangeNotification, object: nil)
        Task { await model.load() }
    }

    @objc private func updateImage() {
        statusItem.button?.image = MenuBarLabel.image(for: status)
    }

    private func observeStatus() {
        withObservationTracking {
            _ = (status.next, status.detail, status.style, status.today)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateImage()
                self?.observeStatus()
            }
        }
    }

    @objc private func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func show() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        SettingsPage.shared.isShown = false
        status.acknowledge()

        let size = content.view.fittingSize
        let icon = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var x = icon.midX - size.width / 2
        if let screen = buttonWindow.screen?.visibleFrame {
            x = min(max(x, screen.minX + Self.screenMargin), screen.maxX - size.width - Self.screenMargin)
        }
        panel.setFrame(NSRect(x: x, y: icon.minY - Self.gap - size.height, width: size.width, height: size.height), display: true)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        if #unavailable(macOS 27) {
            DispatchQueue.main.async {
                button.highlight(true)
            }
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.iconFrame.contains(NSEvent.mouseLocation) else { return }
                self.dismiss()
            }
        }
    }

    private var iconFrame: NSRect {
        guard let button = statusItem.button, let window = button.window else { return .zero }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func dismiss() {
        if #available(macOS 27, *), let session = statusItem.expandedInterfaceSession {
            session.cancel()
        } else {
            hide()
        }
    }

    private func hide() {
        panel.orderOut(nil)
        if #unavailable(macOS 27) {
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.button?.highlight(false)
            }
        }
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}

@available(macOS 27, *)
extension StatusItemController: @MainActor NSStatusItemExpandedInterfaceDelegate {
    func statusItem(_ statusItem: NSStatusItem, didBegin expandedInterfaceSession: NSStatusItemExpandedInterfaceSession) {
        show()
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        hide()
    }
}
