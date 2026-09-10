import Foundation

/// Spotlight-like hotkey: open fresh when hidden, dismiss when already visible.
public enum OverlayHotkeyAction: Equatable, Sendable {
    case showFresh
    case dismiss
}

public enum OverlayHotkeyPolicy: Sendable {
    public static func action(isVisible: Bool) -> OverlayHotkeyAction {
        isVisible ? .dismiss : .showFresh
    }
}
