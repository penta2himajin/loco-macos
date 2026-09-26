import Foundation
import Testing
@testable import LocoMacOSCore

@Suite("FM external adapter")
struct FMAdapterTests {
    private func decision(_ canonical: String) -> Data {
        guard var fields = try? JSONSerialization.jsonObject(with: Data(canonical.utf8)) as? [String: Any] else { return Data(canonical.utf8) }
        fields["action"] = fields["tool_calls"] == nil ? "final_answer" : "tool_call"
        fields["content"] = fields["content"] ?? ""
        fields["tool_calls"] = fields["tool_calls"] ?? []
        return (try? JSONSerialization.data(withJSONObject: fields)) ?? Data(canonical.utf8)
    }
    private func request(_ messages: [[String: Any]], tools: [[String: Any]] = []) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "version": 1, "system": "session background", "messages": messages, "tools": tools,
        ])
    }

    @Test func truncatesOldTurnsAndCountsSchemaBeforeResponding() throws {
        var messages: [[String: Any]] = []
        for n in 0..<12 {
            messages += [["role": "user", "content": "turn-\(n)"], ["role": "assistant", "content": "reply"]]
        }
        messages.removeLast()
        var prompts: [String] = []
        let output = try FMAdapter(contextTokens: 4096).respond(to: request(messages)) { args, input in
            let text = String(decoding: input, as: UTF8.self)
            #expect(args.contains { $0.contains("session background") })
            #expect(!args.contains { $0.contains("Choose action") })
            if args.first == "count-tokens" {
                #expect(text.contains("Response schema:"))
                return Data((text.contains("turn-2\"") ? "99999" : "100").utf8)
            }
            #expect(args.contains("--schema"))
            #expect(args.contains("--no-stream"))
            #expect(args.contains("--greedy"))
            prompts.append(text)
            return Data(#"{"content":"hello"}"#.utf8)
        }
        #expect(String(decoding: output, as: UTF8.self).contains("hello"))
        #expect(prompts.count == 1)
        #expect(!prompts[0].contains("turn-2\""))
        #expect(prompts[0].contains("turn-3\""))
        #expect(prompts[0].contains("turn-11\""))
    }

    @Test func keepsEveryTurnThatFitsTheTokenBudget() throws {
        var messages: [[String: Any]] = []
        for n in 0..<12 {
            messages += [["role": "user", "content": "turn-\(n)"], ["role": "assistant", "content": "reply"]]
        }
        messages.removeLast()
        var prompt = ""
        _ = try FMAdapter(contextTokens: 4096).respond(to: request(messages)) { args, input in
            if args.first == "count-tokens" { return Data("100".utf8) }
            prompt = String(decoding: input, as: UTF8.self)
            return Data(#"{"content":"hello"}"#.utf8)
        }
        #expect(prompt.contains("turn-0\""))
        #expect(prompt.contains("turn-11\""))
    }

    @Test func oversizedCurrentTurnFailsWithoutGeneratingOrTruncating() throws {
        var calls: [String] = []
        #expect(throws: Error.self) {
            _ = try FMAdapter(contextTokens: 4096).respond(to: request([["role": "user", "content": "large"]])) { args, _ in
                calls.append(args[0])
                return Data("99999".utf8)
            }
        }
        #expect(calls == ["count-tokens"])
    }

    @Test func toolContinuationKeepsRequestAndResultTogether() throws {
        let input = try request([
            ["role": "user", "content": "time?"],
            ["role": "assistant", "tool_calls": [["name": "clock", "arguments": [:]]]],
            ["role": "tool", "content": [["name": "clock", "response": ["utc": "12:00"]]]],
        ])
        _ = try FMAdapter(contextTokens: 4096).respond(to: input) { args, data in
            if args[0] == "count-tokens" { return Data("100".utf8) }
            let prompt = String(decoding: data, as: UTF8.self)
            #expect(prompt.contains("clock"))
            #expect(prompt.contains("12:00"))
            return Data(#"{"content":"noon"}"#.utf8)
        }
    }

    @Test func validatesToolNamesArgumentsAndResponseShape() throws {
        let tools: [[String: Any]] = [["type": "function", "function": [
            "name": "open_url", "description": "Open a URL",
            "parameters": ["type": "object", "properties": ["url": ["type": "string"]],
                           "required": ["url"], "additionalProperties": false],
        ]], ["type": "function", "function": [
            "name": "clock", "parameters": ["type": "object", "properties": [:]],
        ]]]
        let input = try request([["role": "user", "content": "open example.com"]], tools: tools)
        for reply in [
            #"{"tool_calls":[{"name":"shell","arguments":{}}]}"#,
            #"{"tool_calls":[{"name":"open_url","arguments":{}}]}"#,
            #"{"tool_calls":[{"name":"open_url","arguments":{"url":42}}]}"#,
            #"{"tool_calls":[]}"#,
            #"{"content":"done","unexpected":true}"#,
            #"{"content":"done","tool_calls":[{"name":"open_url","arguments":{"url":"https://example.com"}}]}"#,
            "not JSON",
        ] {
            #expect(throws: Error.self) {
                _ = try FMAdapter(contextTokens: 4096).respond(to: input) { args, _ in
                    args[0] == "count-tokens" ? Data("100".utf8) : decision(reply)
                }
            }
        }
        let reply = #"{"tool_calls":[{"name":"open_url","arguments":{"url":"https://example.com"}}]}"#
        let output = try FMAdapter(contextTokens: 4096).respond(to: input) { args, _ in
            if args[0] == "respond", let index = args.firstIndex(of: "--schema") {
                let schema = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[index + 1]))) as? [String: Any])
                #expect(schema["title"] as? String == "Response")
                let definitions = try #require(schema["$defs"] as? [String: [String: Any]])
                for definition in definitions.values where definition["type"] as? String == "object" {
                    #expect(definition["required"] is [String])
                    #expect(definition["x-order"] is [String])
                }
            }
            return args[0] == "count-tokens" ? Data("100".utf8) : decision(reply)
        }
        #expect(try JSONDecoder().decode(JSONValue.self, from: output) == JSONDecoder().decode(JSONValue.self, from: Data(reply.utf8)))
    }

    @Test func processHandlesLargeOutputFailureAndTimeout() throws {
        let shell = URL(fileURLWithPath: "/bin/sh")
        let result = try FMProcess.run(executable: shell, arguments: ["-c", "cat; dd if=/dev/zero bs=65536 count=2 2>/dev/null"], input: Data("hello".utf8))
        #expect(result.count == 131077)
        #expect(throws: Error.self) {
            _ = try FMProcess.run(executable: shell, arguments: ["-c", "echo rejected >&2; exit 7"], input: Data())
        }
        #expect(throws: Error.self) {
            _ = try FMProcess.run(executable: shell, arguments: ["-c", "exec sleep 5"], input: Data(), timeout: 0.05)
        }
    }
}
