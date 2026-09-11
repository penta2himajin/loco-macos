import Foundation

/// Where a tool runs. Surfaces own `host` tools; loco-bot may keep portable `local` tools.
public enum ToolExecKind: String, Codable, Sendable, Equatable {
    case host
    case local
}

/// OpenAI-style tool schema advertised to loco-bot via `configure`.
public struct HostToolDefinition: Codable, Sendable, Equatable {
    public var name: String
    public var description: String
    /// JSON Schema object for parameters (serialized as JSON object).
    public var parameters: JSONValue
    public var risk: String
    public var exec: ToolExecKind

    public init(
        name: String,
        description: String,
        parameters: JSONValue = .object([:]),
        risk: String = "medium",
        exec: ToolExecKind = .host
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.risk = risk
        self.exec = exec
    }
}

/// Outbound JSONL messages from the surface → `loco serve` (proposed contract).
public enum ServeClientMessage: Codable, Sendable, Equatable {
    case configure(tools: [HostToolDefinition])
    case turn(user: String)
    case toolResult(callId: String, ok: Bool, content: JSONValue)

    enum CodingKeys: String, CodingKey {
        case op, tools, user
        case callId = "call_id"
        case ok, content
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .configure(tools):
            try c.encode("configure", forKey: .op)
            try c.encode(tools, forKey: .tools)
        case let .turn(user):
            try c.encode("turn", forKey: .op)
            try c.encode(user, forKey: .user)
        case let .toolResult(callId, ok, content):
            try c.encode("tool_result", forKey: .op)
            try c.encode(callId, forKey: .callId)
            try c.encode(ok, forKey: .ok)
            try c.encode(content, forKey: .content)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let op = try c.decode(String.self, forKey: .op)
        switch op {
        case "configure":
            self = .configure(tools: try c.decode([HostToolDefinition].self, forKey: .tools))
        case "turn":
            self = .turn(user: try c.decode(String.self, forKey: .user))
        case "tool_result":
            self = .toolResult(
                callId: try c.decode(String.self, forKey: .callId),
                ok: try c.decode(Bool.self, forKey: .ok),
                content: try c.decodeIfPresent(JSONValue.self, forKey: .content) ?? .object([:])
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .op, in: c, debugDescription: "unknown op \(op)")
        }
    }
}

/// Inbound JSONL from `loco serve` once host-tool handoff exists.
public enum ServeServerMessage: Codable, Sendable, Equatable {
    /// Turn finished (today's single-line TurnOutcome shape, plus status).
    case done(outcome: TurnOutcome)
    /// Model requested a host tool; surface must execute and send `tool_result`.
    case awaitingTool(outcome: TurnOutcome, callId: String)

    enum CodingKeys: String, CodingKey {
        case status, events
        case replyText = "reply_text"
        case callId = "call_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = try c.decodeIfPresent(String.self, forKey: .status) ?? "done"
        let events = try c.decodeIfPresent([AgentEvent].self, forKey: .events) ?? []
        let reply = try c.decodeIfPresent(String.self, forKey: .replyText) ?? ""
        let outcome = TurnOutcome(events: events, replyText: reply)
        switch status {
        case "awaiting_tool":
            let callId = try c.decode(String.self, forKey: .callId)
            self = .awaitingTool(outcome: outcome, callId: callId)
        case "done":
            self = .done(outcome: outcome)
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: c, debugDescription: "unknown status \(status)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .done(outcome):
            try c.encode("done", forKey: .status)
            try c.encode(outcome.events, forKey: .events)
            try c.encode(outcome.replyText, forKey: .replyText)
        case let .awaitingTool(outcome, callId):
            try c.encode("awaiting_tool", forKey: .status)
            try c.encode(callId, forKey: .callId)
            try c.encode(outcome.events, forKey: .events)
            try c.encode(outcome.replyText, forKey: .replyText)
        }
    }
}

/// Catalog of macOS-owned tools the overlay will advertise (v1 seed).
public enum MacHostTools {
    public static let openURL = HostToolDefinition(
        name: "open_url",
        description: "Open a URL in the default macOS browser / handler.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("http(s) URL to open"),
                ]),
            ]),
            "required": .array([.string("url")]),
        ]),
        risk: "medium",
        exec: .host
    )

    public static var v1Catalog: [HostToolDefinition] { [openURL] }
}
