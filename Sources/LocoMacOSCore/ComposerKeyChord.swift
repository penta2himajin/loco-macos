import Foundation

/// Keyboard policy for the overlay composer field.
public enum ComposerKeyChord: Sendable {
    public enum Action: Equatable, Sendable {
        case submit
        case insertNewline
    }

    /// Return without Shift submits; Shift+Return inserts a newline.
    public static func action(returnWithShift: Bool) -> Action {
        returnWithShift ? .insertNewline : .submit
    }
}
