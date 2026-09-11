import Testing
import Foundation
import LocoMacOSCore

@Suite("TurnOutcome JSON")
struct TurnOutcomeJSONTests {
    @Test func decodesDoneOnly() throws {
        let raw = #"""
        {"events":[{"type":"done","text":"hello"}],"reply_text":"hello"}
        """#
        let outcome = try TurnOutcomeJSON.decode(raw)
        #expect(outcome.replyText == "hello")
        #expect(outcome.events == [.done(text: "hello")])
    }

    @Test func decodesClarify() throws {
        let raw = #"""
        {"events":[{"type":"clarify","question":"どの話？","choices":[{"label":"地下鉄","index":1}]}],"reply_text":"どの話？"}
        """#
        let outcome = try TurnOutcomeJSON.decode(raw)
        guard case let .clarify(q, choices) = outcome.events[0] else {
            Issue.record("expected clarify")
            return
        }
        #expect(q == "どの話？")
        #expect(choices.first?.label == "地下鉄")
        #expect(choices.first?.index == 1)
    }

    @Test func decodesToolRequest() throws {
        let raw = #"""
        {"events":[{"type":"tool_request","name":"fs_list","arguments":{"path":"."},"risk":"medium"},{"type":"done","text":"ok"}],"reply_text":"ok"}
        """#
        let outcome = try TurnOutcomeJSON.decode(raw)
        guard case let .toolRequest(name, args, risk) = outcome.events[0] else {
            Issue.record("expected tool_request")
            return
        }
        #expect(name == "fs_list")
        #expect(risk == "medium")
        #expect(args["path"] == .string("."))
    }
}

@Suite("RuntimeConfig")
struct RuntimeConfigTests {
    @Test func serveArgsIncludeBackend() {
        let cfg = RuntimeConfig(backend: .cpu, allowFs: true, fsRoot: "/tmp/sandbox")
        let args = cfg.serveArguments()
        #expect(args.contains("serve"))
        #expect(args.contains("cpu"))
        #expect(args.contains("--allow-fs"))
        #expect(args.contains("/tmp/sandbox"))
    }

    @Test func overlayDefaultIsCpu() {
        #expect(RuntimeConfig.overlayDefault.backend == .cpu)
    }

    @Test func resolvedOverlayDefaultReadsLocoBackendEnv() {
        #expect(RuntimeConfig.resolvedOverlayDefault(environment: [:]).backend == .cpu)
        #expect(RuntimeConfig.resolvedOverlayDefault(environment: ["LOCO_BACKEND": "gpu"]).backend == .gpu)
        #expect(RuntimeConfig.resolvedOverlayDefault(environment: ["LOCO_BACKEND": "metal"]).backend == .gpu)
        #expect(RuntimeConfig.resolvedOverlayDefault(environment: ["LOCO_BACKEND": "cpu"]).backend == .cpu)
        #expect(RuntimeConfig.resolvedOverlayDefault(environment: ["LOCO_BACKEND": "nope"]).backend == .cpu)
    }
}
