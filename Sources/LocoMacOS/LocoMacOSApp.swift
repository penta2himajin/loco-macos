import AppKit
import SwiftUI
import LocoMacOSCore

@main
struct LocoMacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var overlayVM = OverlayViewModel()
    private let hotkey = HotkeyRegistrar()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPanel()
        do {
            try hotkey.register { [weak self] in
                Task { @MainActor in
                    self?.toggleOverlay()
                }
            }
        } catch {
            overlayVM.status = "Hotkey failed (\(error)). Use menu bar."
        }
        // Warm runtime on launch (cpu by default — avoid contending for GPU).
        overlayVM.ensureRuntime()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.unregister()
        overlayVM.stopRuntime()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "loco"
            button.action = #selector(toggleOverlay)
            button.target = self
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func setupPanel() {
        let hosting = NSHostingView(rootView: OverlayPanelView(vm: overlayVM) { [weak self] in
            self?.hideOverlay()
        })
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "loco"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        panel.center()
        self.panel = panel
    }

    @objc private func toggleOverlay() {
        guard let panel else { return }
        if panel.isVisible {
            if overlayVM.isPinned { return }
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        guard let panel else { return }
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayVM.ensureRuntime()
    }

    private func hideOverlay() {
        if overlayVM.isPinned { return }
        panel?.orderOut(nil)
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.midY + frame.height * 0.12 - size.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
