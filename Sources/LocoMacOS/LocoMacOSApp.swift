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
    private var panel: KeyablePanel?
    private var backdrop: NSWindow?
    private var overlayVM = OverlayViewModel()
    private let hotkey = HotkeyRegistrar()
    private var escapeMonitor: Any?
    /// Keeps NSPanel content size in sync when reply/clarify expands the SwiftUI body.
    private var frameController = PanelFrameController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupBackdrop()
        setupPanel()
        installEscapeMonitor()
        observePresentationChanges()
        do {
            try hotkey.register { [weak self] in
                self?.toggleOverlay()
            }
            if !hotkey.isOverridingSystemShortcut {
                overlayVM.status =
                    "⌃⌘Space needs Accessibility to override emoji picker — open Privacy settings from the menu."
            }
        } catch {
            overlayVM.status = "Hotkey failed (\(error)). Use menu bar."
        }
        overlayVM.ensureRuntime()
        showOverlay()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.unregister()
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
        overlayVM.stopRuntime()
    }

    private func setupStatusItem() {
        // Variable length so icon + short label both fit in the menu bar.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            if let image = NSImage(
                systemSymbolName: "sparkle.magnifyingglass",
                accessibilityDescription: "loco"
            ) {
                image.isTemplate = true
                button.image = image.withSymbolConfiguration(config)
                button.imagePosition = .imageLeading
            }
            button.title = "loco"
            button.toolTip = "loco — ⌃⌘Space"
            button.appearsDisabled = false
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(
            NSMenuItem(
                title: "Enable Accessibility for ⌃⌘Space…",
                action: #selector(openAccessibility),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit loco", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        // Keep a strong reference; losing this removes the menu-bar item.
        statusItem = item
    }

    private func setupBackdrop() {
        let screen = NSScreen.main?.frame ?? .zero
        let win = NSWindow(
            contentRect: screen,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = NSColor.black.withAlphaComponent(0.22)
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        win.ignoresMouseEvents = false
        win.hidesOnDeactivate = false

        let click = NSClickGestureRecognizer(target: self, action: #selector(backdropClicked))
        win.contentView?.wantsLayer = true
        win.contentView?.addGestureRecognizer(click)
        backdrop = win
    }

    private func setupPanel() {
        let hosting = NSHostingView(
            rootView: OverlayPanelView(
                vm: overlayVM,
                onDismiss: { [weak self] in
                    self?.hideOverlay()
                },
                onMeasuredSize: { [weak self] size in
                    self?.applyMeasuredContentSize(size)
                }
            )
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        let initial = frameController.contentSize
        hosting.frame = NSRect(origin: .zero, size: initial)

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: initial),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentView = hosting
        self.panel = panel
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 53 == Escape
            if event.keyCode == 53 {
                Task { @MainActor in
                    self?.hideOverlay()
                }
                return nil
            }
            return event
        }
    }

    @objc private func backdropClicked() {
        hideOverlay()
    }

    @objc private func toggleOverlay() {
        guard let panel else { return }
        if panel.isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        guard let panel, let backdrop else { return }
        if let screen = NSScreen.main {
            backdrop.setFrame(screen.frame, display: true)
        }
        backdrop.orderFront(nil)
        syncPanelFrameFromPresentation(force: true)
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayVM.ensureRuntime()
        // Re-focus search field via view refresh.
        panel.contentView?.needsDisplay = true
    }

    private func hideOverlay() {
        backdrop?.orderOut(nil)
        panel?.orderOut(nil)
    }

    /// Re-arms Observation tracking so reply/status growth resizes the panel without reopen.
    private func observePresentationChanges() {
        withObservationTracking {
            _ = overlayVM.reply
            _ = overlayVM.clarifyChoices.count
            _ = overlayVM.status
            _ = overlayVM.isBusy
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.syncPanelFrameFromPresentation(force: false)
                self?.observePresentationChanges()
            }
        }
    }

    private func currentPresentation() -> OverlayPresentation {
        OverlayPresentation(
            reply: overlayVM.reply,
            clarifyCount: overlayVM.clarifyChoices.count,
            status: overlayVM.status
        )
    }

    private func syncPanelFrameFromPresentation(force: Bool) {
        let changed = frameController.apply(currentPresentation())
        guard force || changed else { return }
        applyPanelContentSize(frameController.contentSize)
    }

    private func applyMeasuredContentSize(_ size: CGSize) {
        // Prefer the larger of preferred math vs measured SwiftUI size so short
        // fittingSize after a reply cannot shrink the panel again.
        let preferred = currentPresentation().preferredPanelSize
        let merged = CGSize(
            width: max(size.width, preferred.width),
            height: max(size.height, preferred.height)
        )
        guard frameController.applyMeasured(merged) else { return }
        applyPanelContentSize(frameController.contentSize)
    }

    private func applyPanelContentSize(_ size: CGSize) {
        guard let panel else { return }
        panel.setContentSize(size)
        if panel.isVisible {
            positionPanel(panel)
        }
    }

    private func positionPanel(_ panel: KeyablePanel) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        panel.layoutIfNeeded()
        // Prefer frameController size. fittingSize alone often stays at the
        // search-only height until the panel is reopened — the user-visible bug.
        var size = frameController.contentSize
        if let hosting = panel.contentView {
            let fitting = hosting.fittingSize
            if fitting.width > 0, fitting.height > size.height {
                size = CGSize(width: max(fitting.width, OverlayPresentation.panelWidth), height: fitting.height)
                _ = frameController.applyMeasured(size)
            }
        }
        panel.setContentSize(size)
        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = frame.midX - panelSize.width / 2
        // Upper third, Spotlight-like.
        let y = frame.minY + frame.height * 0.62 - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func openAccessibility() {
        HotkeyRegistrar.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Borderless panels normally refuse key focus; allow typing in the search field.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
