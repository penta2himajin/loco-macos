/// Shared types matching loco-bot `loco_agent::AgentEvent` / `TurnOutcome` JSON.
/// SoT: https://github.com/penta2himajin/loco-bot/blob/main/docs/macos-overlay.md

import Foundation

public struct TurnOutcome: Codable, Sendable, Equatable {
    public var events: [AgentEvent]
    public var replyText: String

    enum CodingKeys: String, CodingKey {
        case events
        case replyText = "reply_text"
    }

    public init(events: [AgentEvent], replyText: String) {
        self.events = events
        self.replyText = replyText
    }
}

public struct ClarifyChoice: Codable, Sendable, Equatable {
    public var label: String
    public var index: Int
}

public enum AgentEvent: Codable, Sendable, Equatable {
    case clarify(question: String, choices: [ClarifyChoice])
    case ack(text: String)
    case topic(kind: String, chunkIndex: Int?)
    case context(chars: Int, hasDynamic: Bool)
    case toolRequest(name: String, arguments: [String: JSONValue], risk: String)
    case toolResult(name: String, ok: Bool)
    case token(delta: String)
    case done(text: String)

    enum CodingKeys: String, CodingKey {
        case type
        case question, choices, text, kind
        case chunkIndex = "chunk_index"
        case chars
        case hasDynamic = "has_dynamic"
        case name, arguments, risk, ok, delta
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "clarify":
            self = .clarify(
                question: try c.decode(String.self, forKey: .question),
                choices: try c.decode([ClarifyChoice].self, forKey: .choices)
            )
        case "ack":
            self = .ack(text: try c.decode(String.self, forKey: .text))
        case "topic":
            self = .topic(
                kind: try c.decode(String.self, forKey: .kind),
                chunkIndex: try c.decodeIfPresent(Int.self, forKey: .chunkIndex)
            )
        case "context":
            self = .context(
                chars: try c.decode(Int.self, forKey: .chars),
                hasDynamic: try c.decode(Bool.self, forKey: .hasDynamic)
            )
        case "tool_request":
            self = .toolRequest(
                name: try c.decode(String.self, forKey: .name),
                arguments: try c.decodeIfPresent([String: JSONValue].self, forKey: .arguments) ?? [:],
                risk: try c.decode(String.self, forKey: .risk)
            )
        case "tool_result":
            self = .toolResult(
                name: try c.decode(String.self, forKey: .name),
                ok: try c.decode(Bool.self, forKey: .ok)
            )
        case "token":
            self = .token(delta: try c.decode(String.self, forKey: .delta))
        case "done":
            self = .done(text: try c.decode(String.self, forKey: .text))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "unknown event type \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .clarify(question, choices):
            try c.encode("clarify", forKey: .type)
            try c.encode(question, forKey: .question)
            try c.encode(choices, forKey: .choices)
        case let .ack(text):
            try c.encode("ack", forKey: .type)
            try c.encode(text, forKey: .text)
        case let .topic(kind, chunkIndex):
            try c.encode("topic", forKey: .type)
            try c.encode(kind, forKey: .kind)
            try c.encodeIfPresent(chunkIndex, forKey: .chunkIndex)
        case let .context(chars, hasDynamic):
            try c.encode("context", forKey: .type)
            try c.encode(chars, forKey: .chars)
            try c.encode(hasDynamic, forKey: .hasDynamic)
        case let .toolRequest(name, arguments, risk):
            try c.encode("tool_request", forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(arguments, forKey: .arguments)
            try c.encode(risk, forKey: .risk)
        case let .toolResult(name, ok):
            try c.encode("tool_result", forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(ok, forKey: .ok)
        case let .token(delta):
            try c.encode("token", forKey: .type)
            try c.encode(delta, forKey: .delta)
        case let .done(text):
            try c.encode("done", forKey: .type)
            try c.encode(text, forKey: .text)
        }
    }
}

/// Minimal JSON value for tool argument maps.
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case let .bool(b): try c.encode(b)
        case let .number(n): try c.encode(n)
        case let .string(s): try c.encode(s)
        case let .object(o): try c.encode(o)
        case let .array(a): try c.encode(a)
        }
    }
}
