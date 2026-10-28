import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private static let gap: CGFloat = 6
    private static let screenMargin: CGFloat = 8
    private static let resizeDuration: TimeInterval = 0.3
    private static let reopenGuard: TimeInterval = 0.3

    private let model = TimetableModel()
    private let status: MenuBarStatus
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let content: NSHostingController<PopUpContent>
    private let panel = PopUpPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private var clickMonitor: Any?
    private var sheetClickMonitor: Any?
    private var hiddenAt = Date.distantPast

    override init() {
        status = MenuBarStatus(model: model)
        content = NSHostingController(rootView: PopUpContent(model: model))
        content.sizingOptions = []
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
        observeSettingsPage()
        closeSheetOnOutsideClicks()
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        Task { await model.load() }
    }

    private func closeSheetOnOutsideClicks() {
        sheetClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let window = event.window
            let handled = MainActor.assumeIsolated {
                guard let self, window != nil, window == self.panel, TimesExplanation.shared.isShown else { return false }
                TimesExplanation.shared.isShown = false
                return true
            }
            return handled ? nil : event
        }
    }

    @objc private func defaultsChanged() {
        updateImage()
        DispatchQueue.main.async { [weak self] in
            self?.resize()
        }
    }

    private func updateImage() {
        statusItem.button?.image = MenuBarLabel.image(for: status)
    }

    private var width: CGFloat {
        let showsCalendar = UserDefaults.standard.bool(forKey: MenuBarDate.showsKey) && !SettingsPage.shared.isShown
        return SunPathView.timetableWidth + (showsCalendar ? CalendarView.width : 0)
    }

    private func observeSettingsPage() {
        withObservationTracking {
            _ = SettingsPage.shared.isShown
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.resize()
                self?.observeSettingsPage()
            }
        }
    }

    private func frame() -> NSRect {
        let icon = iconFrame
        let alignment = UserDefaults.standard.string(forKey: PopUpAlignment.key).flatMap(PopUpAlignment.init) ?? .center
        var x = alignment.x(width: width, under: icon)
        if let screen = statusItem.button?.window?.screen?.visibleFrame {
            x = min(max(x, screen.minX + Self.screenMargin), screen.maxX - width - Self.screenMargin)
        }
        return NSRect(x: x, y: icon.minY - Self.gap - PopUpContent.height, width: width, height: PopUpContent.height)
    }

    private func resize() {
        let frame = frame()
        guard panel.isVisible, panel.frame != frame else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.resizeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
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
        if panel.isVisible {
            hide()
        } else if Date.now.timeIntervalSince(hiddenAt) > Self.reopenGuard {
            show()
        }
    }

    private func show() {
        guard let button = statusItem.button else { return }
        SettingsPage.shared.isShown = false
        TimesExplanation.shared.isShown = false
        status.acknowledge()

        panel.setFrame(frame(), display: true)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        if #unavailable(macOS 27) {
            DispatchQueue.main.async {
                button.highlight(true)
            }
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismiss()
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
        if panel.isVisible {
            hiddenAt = .now
        }
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
        guard Date.now.timeIntervalSince(hiddenAt) > Self.reopenGuard else {
            expandedInterfaceSession.cancel()
            return
        }
        show()
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        hide()
    }
}
