import CoreGraphics
import Foundation

/// Reply body viewport: grow with content up to ``maxVisibleLines``, then scroll.
public enum ReplyLayout: Sendable {
    /// Visible lines before scrolling (user-requested initial cap).
    public static let maxVisibleLines: Int = 15
    /// Approximate line height for 15pt body text.
    public static let lineHeight: CGFloat = 22
    /// Rough wrap width for the overlay body (~640pt − padding).
    public static let charsPerLine: Int = 48

    public static var maxViewportHeight: CGFloat {
        CGFloat(maxVisibleLines) * lineHeight
    }

    /// Counts soft-wrapped lines (newlines + wrap at ``charsPerLine``).
    public static func lineCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)
        var total = 0
        for paragraph in paragraphs {
            let chars = paragraph.count
            if chars == 0 {
                total += 1
            } else {
                total += max(1, (chars + charsPerLine - 1) / charsPerLine)
            }
        }
        return total
    }

    /// Height of the reply viewport: content height capped at ``maxVisibleLines``.
    public static func viewportHeight(for text: String) -> CGFloat {
        let lines = min(max(1, lineCount(for: text)), maxVisibleLines)
        return CGFloat(lines) * lineHeight
    }

    public static func needsScroll(for text: String) -> Bool {
        lineCount(for: text) > maxVisibleLines
    }
}

/// Placeholder shown in the composer when the draft is empty.
public enum ComposerPlaceholder: Sendable {
    public static let idle = "Ask loco…"

    /// After a send, keep the submitted prompt as a faint placeholder until the next edit.
    public static func text(draft: String, lastSubmitted: String) -> String {
        if draft.isEmpty, !lastSubmitted.isEmpty {
            return lastSubmitted
        }
        return idle
    }
}
