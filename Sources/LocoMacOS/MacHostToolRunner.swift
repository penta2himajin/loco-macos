import AppKit
import Foundation
import LocoMacOSCore

/// Runs macOS host tools advertised via `MacHostTools`.
enum MacHostToolRunner {
    static func execute(name: String, arguments: [String: JSONValue]) -> (ok: Bool, content: JSONValue) {
        switch name {
        case OpenURLTool.name:
            return openURL(arguments: arguments)
        default:
            return (false, .object([
                "error": .string("unknown host tool"),
                "tool": .string(name),
            ]))
        }
    }

    private static func openURL(arguments: [String: JSONValue]) -> (ok: Bool, content: JSONValue) {
        guard let url = OpenURLTool.url(from: arguments) else {
            return (false, OpenURLTool.failureContent("missing or invalid http(s) url"))
        }
        let ok = NSWorkspace.shared.open(url)
        if ok {
            return (true, OpenURLTool.successContent(opened: url))
        }
        return (false, OpenURLTool.failureContent("NSWorkspace failed to open url"))
    }
}
