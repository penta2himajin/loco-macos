import AppKit
import Carbon
import Foundation

/// Default chord: ⌃⌥Space (Control + Option + Space).
/// Avoids Spotlight (⌘Space) and the system Character Viewer (⌃⌘Space).
public enum OverlayHotkey {
    public static let displayName = "⌃⌥Space"
    /// Carbon modifiers for RegisterEventHotKey.
    public static var carbonModifiers: UInt32 { UInt32(controlKey | optionKey) }
    public static var keyCode: UInt32 { UInt32(kVK_Space) }
}

/// Registers the overlay global hotkey via Carbon.
public final class HotkeyRegistrar {
    public typealias Handler = () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handler: Handler?

    public init() {}

    deinit {
        unregister()
    }

    public func register(handler: @escaping Handler) throws {
        unregister()
        self.handler = handler

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
                    registrar.handler?()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
        guard status == noErr else {
            throw HotkeyError.installFailed(status)
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C_4F_43_4F), id: 1) // 'LOCO'
        let registerStatus = RegisterEventHotKey(
            OverlayHotkey.keyCode,
            OverlayHotkey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            throw HotkeyError.registerFailed(registerStatus)
        }
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        handler = nil
    }
}

public enum HotkeyError: Error {
    case installFailed(OSStatus)
    case registerFailed(OSStatus)
}
