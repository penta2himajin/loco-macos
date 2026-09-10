import Foundation

/// Keyboard policy for the overlay composer field.
public enum ComposerKeyChord: Sendable {
    public enum Action: Equatable, Sendable {
        case submit
        case insertNewline
        case historyUp
        case historyDown
        case ignored
    }

    /// ⌘↩ submits; plain Return inserts a newline (Shift+Return likewise).
    public static func action(returnWithCommand: Bool) -> Action {
        returnWithCommand ? .submit : .insertNewline
    }

    /// ↑/↓ browse history when the draft is empty, or while already browsing
    /// (draft then holds the prior prompt as editable text).
    public static func action(
        arrowUp: Bool,
        arrowDown: Bool,
        draftIsEmpty: Bool,
        browsingHistory: Bool
    ) -> Action {
        guard draftIsEmpty || browsingHistory else { return .ignored }
        if arrowUp { return .historyUp }
        if arrowDown { return .historyDown }
        return .ignored
    }
}
