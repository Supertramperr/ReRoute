import AppKit
import SwiftUI
import QuartzCore

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var settingsWC: NSWindowController?
    private var aboutWC: NSWindowController?

    func showSettings(model: AppModel) {
        let root = SettingsView().environmentObject(model)
        let host = NSHostingController(rootView: root)

        let win = NSWindow(contentViewController: host)
        win.title = "ReRoute Settings"

        // Borderless glass window (we provide our own chrome)
        win.styleMask = [.borderless, .resizable, .miniaturizable]
        win.isReleasedWhenClosed = false

        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isMovableByWindowBackground = true

        let size = NSSize(width: 320, height: 320)
        win.setContentSize(size)
        win.minSize = size
        win.maxSize = size

        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Use a layer MASK (not cornerRadius+masksToBounds) to avoid the “outer rect”/double-frame artifact.
        DispatchQueue.main.async {
            self.applySquircleMask(to: win, radius: 20)
            win.makeFirstResponder(nil)
        }

        settingsWC = NSWindowController(window: win)
    }

    func showAbout() {
        let host = NSHostingController(rootView: AboutView())
        let win = NSWindow(contentViewController: host)
        win.title = "About ReRoute"

        win.styleMask = [.borderless, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isMovableByWindowBackground = true

        let size = NSSize(width: 280, height: 242)
        win.setContentSize(size)
        win.minSize = size
        win.maxSize = size

        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            self.applySquircleMask(to: win, radius: 20)
            win.makeFirstResponder(nil)
        }

        aboutWC = NSWindowController(window: win)
    }


    private func applySquircleMask(to window: NSWindow, radius: CGFloat) {
        guard let cv = window.contentView else { return }
        cv.wantsLayer = true
        guard let layer = cv.layer else { return }

        // IMPORTANT: do NOT set cornerRadius or masksToBounds here.
        layer.cornerRadius = 0
        layer.masksToBounds = false

        let bounds = cv.bounds
        let path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)

        let mask = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        mask.path = path
        mask.fillColor = NSColor.black.cgColor
        mask.contentsScale = window.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        layer.mask = mask

        // Recompute once more after layout to ensure no 1px “outer rect”.
        cv.layoutSubtreeIfNeeded()
        mask.path = CGPath(roundedRect: cv.bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)

        window.invalidateShadow()
    }
}
