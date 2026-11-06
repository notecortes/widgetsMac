import SwiftUI
import AppKit

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    public func show() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openSettings()
            return
        }

        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Ajustes de Pulse Monitor"
        win.contentViewController = hostingController
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.level = .floating
        win.center()

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.orderOut(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        // Window closed by user
    }
}
