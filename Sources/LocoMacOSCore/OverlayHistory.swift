import Foundation

/// One completed overlay turn (prompt + reply) for history browsing.
public struct OverlayTurn: Equatable, Sendable {
    public var prompt: String
    public var reply: String

    public init(prompt: String, reply: String) {
        self.prompt = prompt
        self.reply = reply
    }
}

/// Shell-style history for the overlay: live/initial is empty; ↑ older, ↓ newer / back to live.
public struct OverlayHistoryNavigator: Equatable, Sendable {
    public private(set) var entries: [OverlayTurn]
    /// `nil` = live/initial (empty composer). Otherwise index into `entries` (0 = oldest).
    public private(set) var browsingIndex: Int?

    public init(entries: [OverlayTurn] = [], browsingIndex: Int? = nil) {
        self.entries = entries
        self.browsingIndex = browsingIndex
    }

    public var isLive: Bool { browsingIndex == nil }

    public var current: OverlayTurn? {
        guard let browsingIndex else { return nil }
        return entries[browsingIndex]
    }

    /// Hotkey / reopen: empty composer, not browsing.
    public mutating func resetToInitial() {
        browsingIndex = nil
    }

    /// After a successful turn: append and stay on that entry (visible as history tip).
    public mutating func record(_ turn: OverlayTurn) {
        entries.append(turn)
        browsingIndex = entries.count - 1
    }

    /// ↑ — from live → newest; from an entry → older. No-op at oldest.
    @discardableResult
    public mutating func moveUp() -> Bool {
        guard !entries.isEmpty else { return false }
        if let browsingIndex {
            guard browsingIndex > 0 else { return false }
            self.browsingIndex = browsingIndex - 1
        } else {
            browsingIndex = entries.count - 1
        }
        return true
    }

    /// ↓ — toward newer entries; from newest → live/initial. No-op while already live.
    @discardableResult
    public mutating func moveDown() -> Bool {
        guard let browsingIndex else { return false }
        if browsingIndex + 1 < entries.count {
            self.browsingIndex = browsingIndex + 1
        } else {
            self.browsingIndex = nil
        }
        return true
    }
}
