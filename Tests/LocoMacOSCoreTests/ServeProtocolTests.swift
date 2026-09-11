import Testing
import Foundation
import LocoMacOSCore

@Suite("Host tool serve protocol")
struct ServeProtocolTests {
    @Test func configureEncodesHostToolsForLocoBot() throws {
        let msg = ServeClientMessage.configure(tools: MacHostTools.v1Catalog)
        let data = try JSONEncoder().encode(msg)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["op"] as? String == "configure")
        let tools = obj?["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?.first?["name"] as? String == "open_url")
        #expect(tools?.first?["exec"] as? String == "host")
        #expect(tools?.first?["risk"] as? String == "medium")
    }

    @Test func toolResultRoundTripsCallId() throws {
        let msg = ServeClientMessage.toolResult(
            callId: "c1",
            ok: true,
            content: .object(["opened": .bool(true)])
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServeClientMessage.self, from: data)
        guard case let .toolResult(callId, ok, content) = decoded else {
            Issue.record("expected tool_result")
            return
        }
        #expect(callId == "c1")
        #expect(ok)
        #expect(content == .object(["opened": .bool(true)]))
    }

    @Test func awaitingToolStatusRequiresCallId() throws {
        let json = Data(
            """
            {"status":"awaiting_tool","call_id":"c42","events":[{"type":"tool_request","name":"open_url","arguments":{"url":"https://example.com"},"risk":"medium"}],"reply_text":""}
            """.utf8
        )
        let msg = try JSONDecoder().decode(ServeServerMessage.self, from: json)
        guard case let .awaitingTool(outcome, callId) = msg else {
            Issue.record("expected awaiting_tool")
            return
        }
        #expect(callId == "c42")
        #expect(outcome.events.count == 1)
        guard case let .toolRequest(name, args, risk) = outcome.events[0] else {
            Issue.record("expected tool_request event")
            return
        }
        #expect(name == "open_url")
        #expect(risk == "medium")
        #expect(args["url"] == .string("https://example.com"))
    }

    @Test func doneStatusMatchesLegacyTurnOutcomeShape() throws {
        let json = Data(
            """
            {"status":"done","events":[{"type":"done","text":"ok"}],"reply_text":"ok"}
            """.utf8
        )
        let msg = try JSONDecoder().decode(ServeServerMessage.self, from: json)
        guard case let .done(outcome) = msg else {
            Issue.record("expected done")
            return
        }
        #expect(outcome.replyText == "ok")
    }

    @Test func macCatalogIsHostExecutedOnly() {
        for tool in MacHostTools.v1Catalog {
            #expect(tool.exec == .host)
            #expect(!tool.name.isEmpty)
        }
    }
}
