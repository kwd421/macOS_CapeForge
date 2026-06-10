import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = CursorController()
    private var hasOpenedSettingsOnLaunch = false
    private lazy var settingsWindowController = SettingsWindowController(controller: controller)

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        NSApp.setActivationPolicy(.regular)
        // Defer activation until the app has fully finished launching so the
        // settings window reliably becomes key/frontmost in archived builds.
        DispatchQueue.main.async { [weak self] in
            self?.openSettingsIfNeeded()
        }
    }

    func openSettingsWindow() {
        settingsWindowController.showWindow(nil)
        settingsWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSettingsIfNeeded() {
        guard !hasOpenedSettingsOnLaunch else { return }
        hasOpenedSettingsOnLaunch = true
        openSettingsWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    // Nudge the traffic lights right/down so they sit comfortably inside the
    // rounded sidebar card instead of hugging the window corner.
    private static let trafficLightOffset = NSPoint(x: 10, y: -10)
    private var defaultTrafficLightOrigins: [NSWindow.ButtonType: NSPoint] = [:]

    init(controller: CursorController) {
        let contentView = SettingsView(controller: controller)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Cursie"
        window.setContentSize(NSSize(width: 920, height: 680))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        // Hide the native titlebar entirely: content extends to the window top
        // and the traffic lights float over the sidebar card.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        DispatchQueue.main.async { [weak self] in
            self?.repositionTrafficLights()
        }
    }

    // AppKit resets the standard buttons to their default spots on every
    // layout pass, so re-apply the offset whenever the window resizes.
    func windowDidResize(_ notification: Notification) {
        repositionTrafficLights()
    }

    private func repositionTrafficLights() {
        guard let window else { return }
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(type) else { continue }
            let defaultOrigin = defaultTrafficLightOrigins[type] ?? button.frame.origin
            defaultTrafficLightOrigins[type] = defaultOrigin
            button.setFrameOrigin(NSPoint(
                x: defaultOrigin.x + Self.trafficLightOffset.x,
                y: defaultOrigin.y + Self.trafficLightOffset.y
            ))
        }
    }
}
