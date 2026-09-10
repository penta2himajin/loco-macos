import AppKit
import ApplicationServices
import Carbon
import Foundation

/// Default chord: ⌃⌘Space (Control + Command + Space).
/// Overrides the system Character Viewer when an event tap is allowed
/// (Accessibility permission).
public enum OverlayHotkey {
    public static let displayName = "⌃⌘Space"
    public static var keyCode: Int64 { Int64(kVK_Space) }

    public static func matches(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Self.keyCode else { return false }
        let flags = event.flags
        let wantsControl = flags.contains(.maskControl)
        let wantsCommand = flags.contains(.maskCommand)
        let noOption = !flags.contains(.maskAlternate)
        let noShift = !flags.contains(.maskShift)
        return wantsControl && wantsCommand && noOption && noShift
    }
}

/// Intercepts ⌃⌘Space via a session event tap so Character Viewer does not win.
public final class HotkeyRegistrar: @unchecked Sendable {
    public typealias Handler = @MainActor () -> Void

    private let lock = NSLock()
    private var handler: Handler?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var carbonHotKeyRef: EventHotKeyRef?
    private var carbonHandlerRef: EventHandlerRef?
    private var lastFire = Date.distantPast

    /// True when Accessibility event tap is active (can swallow system shortcuts).
    public private(set) var isOverridingSystemShortcut = false

    public init() {}

    deinit {
        unregister()
    }

    @MainActor
    public func register(handler: @escaping Handler) throws {
        unregister()
        lock.lock()
        self.handler = handler
        lock.unlock()

        // Prompt only when Accessibility is not yet granted. Passing
        // AXTrustedCheckOptionPrompt=true while already trusted can still
        // resurface the system dialog on some macOS builds.
        if !AXIsProcessTrusted() {
            let prompt = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(prompt)
        }

        if tryInstallEventTap() {
            isOverridingSystemShortcut = true
            return
        }

        isOverridingSystemShortcut = false
        try registerCarbonFallback()
    }

    public func unregister() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.tap = nil
        }
        if let carbonHotKeyRef {
            UnregisterEventHotKey(carbonHotKeyRef)
            self.carbonHotKeyRef = nil
        }
        if let carbonHandlerRef {
            RemoveEventHandler(carbonHandlerRef)
            self.carbonHandlerRef = nil
        }
        lock.lock()
        handler = nil
        lock.unlock()
        isOverridingSystemShortcut = false
    }

    /// Opens System Settings → Privacy → Accessibility for this app.
    public static func openAccessibilitySettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    private func fireHandler() {
        // Debounce key-repeat / double delivery so the panel does not flash.
        let now = Date()
        lock.lock()
        defer { lock.unlock() }
        if now.timeIntervalSince(lastFire) < 0.35 {
            return
        }
        lastFire = now
        let handler = self.handler
        Task { @MainActor in
            handler?()
        }
    }

    // MARK: - Event tap (preferred)

    private func tryInstallEventTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let registrar = Unmanaged<HotkeyRegistrar>.fromOpaque(userInfo).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = registrar.tap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown, OverlayHotkey.matches(event) else {
                    return Unmanaged.passUnretained(event)
                }

                // Autorepeat: ignore so hold does not toggle open/close.
                if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                    return nil
                }

                registrar.fireHandler()
                return nil
            },
            userInfo: userInfo
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
        return true
    }

    // MARK: - Carbon fallback (cannot reliably beat Character Viewer)

    private func registerCarbonFallback() throws {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return noErr }
                let registrar = Unmanaged<HotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    registrar.fireHandler()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &carbonHandlerRef
        )
        guard status == noErr else {
            throw HotkeyError.installFailed(status)
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C_4F_43_4F), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &carbonHotKeyRef
        )
        guard registerStatus == noErr else {
            throw HotkeyError.registerFailed(registerStatus)
        }
    }
}

public enum HotkeyError: Error {
    case installFailed(OSStatus)
    case registerFailed(OSStatus)
}
