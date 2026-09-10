import CoreGraphics
import Foundation

/// Pure presentation math for the overlay panel.
///
/// The floating `NSPanel` does not reliably grow with `NSHostingView` when
/// SwiftUI content expands after a reply arrives. Callers must apply
/// `preferredPanelSize` (or a measured size) whenever this state changes —
/// reopening the panel works today because `showOverlay` repositions/resizes.
public struct OverlayPresentation: Equatable, Sendable {
    public var reply: String
    public var clarifyCount: Int
    public var status: String

    public init(reply: String = "", clarifyCount: Int = 0, status: String = "Ready") {
        self.reply = reply
        self.clarifyCount = clarifyCount
        self.status = status
    }

    public var hasError: Bool {
        status.hasPrefix("Error") || status.hasPrefix("Runtime failed")
    }

    public var showsBody: Bool {
        !reply.isEmpty || clarifyCount > 0 || hasError
    }

    public static let panelWidth: CGFloat = 640
    /// Approximate height of the search row alone (padding + field).
    public static let searchOnlyHeight: CGFloat = 56

    /// Preferred panel content size for the current presentation.
    /// Expanded height must exceed ``searchOnlyHeight`` when `showsBody` is true.
    public var preferredPanelSize: CGSize {
        guard showsBody else {
            return CGSize(width: Self.panelWidth, height: Self.searchOnlyHeight)
        }

        var height = Self.searchOnlyHeight + 1 + 22 // divider + body padding
        if clarifyCount > 0 {
            height += CGFloat(clarifyCount) * 44
        }
        if !reply.isEmpty {
            // Same viewport math as the SwiftUI ScrollView — first paint and reopen agree.
            height += ReplyLayout.viewportHeight(for: reply)
        }
        if hasError, reply.isEmpty {
            height += 36
        }
        return CGSize(width: Self.panelWidth, height: height)
    }
}

/// Tracks the last applied panel content size and reports when a resize is required.
public struct PanelFrameController: Equatable, Sendable {
    public private(set) var contentSize: CGSize

    public init(contentSize: CGSize = CGSize(width: OverlayPresentation.panelWidth, height: OverlayPresentation.searchOnlyHeight)) {
        self.contentSize = contentSize
    }

    /// Updates `contentSize` from presentation. Returns `true` when the panel frame must change.
    @discardableResult
    public mutating func apply(_ presentation: OverlayPresentation) -> Bool {
        let preferred = presentation.preferredPanelSize
        let changed =
            abs(preferred.width - contentSize.width) > 0.5
            || abs(preferred.height - contentSize.height) > 0.5
        if changed {
            contentSize = preferred
        }
        return changed
    }

    /// Applies a measured SwiftUI size (from geometry), clamped to panel width.
    @discardableResult
    public mutating func applyMeasured(_ size: CGSize) -> Bool {
        let next = CGSize(width: max(size.width, OverlayPresentation.panelWidth), height: max(size.height, OverlayPresentation.searchOnlyHeight))
        let changed =
            abs(next.width - contentSize.width) > 0.5
            || abs(next.height - contentSize.height) > 0.5
        if changed {
            contentSize = next
        }
        return changed
    }
}
