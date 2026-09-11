import Foundation

/// Pure helpers for the macOS `open_url` host tool (no AppKit).
public enum OpenURLTool: Sendable {
    public static let name = "open_url"

    /// Extract an http(s) URL from tool arguments.
    public static func url(from arguments: [String: JSONValue]) -> URL? {
        guard case let .string(raw)? = arguments["url"] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }

    public static func failureContent(_ message: String) -> JSONValue {
        .object(["error": .string(message), "tool": .string(name)])
    }

    public static func successContent(opened: URL) -> JSONValue {
        .object([
            "opened": .bool(true),
            "url": .string(opened.absoluteString),
        ])
    }
}
