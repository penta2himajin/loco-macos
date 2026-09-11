import Foundation
import Observation
import LocoMacOSCore

@MainActor
@Observable
final class OverlayViewModel {
    var draft: String = ""
    /// Last prompt sent; shown as faint TextField placeholder after the draft is cleared.
    var lastSubmittedPrompt: String = ""
    var reply: String = ""
    var status: String = "Ready"
    var isBusy: Bool = false
    var clarifyChoices: [ClarifyChoice] = []

    private(set) var history = OverlayHistoryNavigator()

    var composerPlaceholder: String {
        ComposerPlaceholder.text(draft: draft, lastSubmitted: lastSubmittedPrompt)
    }

    private let client: LocoServeClient
    private let config: RuntimeConfig

    init(config: RuntimeConfig = .resolvedOverlayDefault()) {
        self.config = config
        self.client = LocoServeClient(config: config)
    }

    func ensureRuntime() {
        guard !client.isRunning else { return }
        do {
            try client.start()
            try client.ensureConfigured(tools: MacHostTools.v1Catalog)
            status = "Runtime warm (\(config.backend.rawValue))"
        } catch {
            status = "Runtime failed: \(error.localizedDescription). Is `loco` on PATH?"
        }
    }

    func stopRuntime() {
        client.stop()
        status = "Runtime stopped"
    }

    /// ⌃⌘Space: empty composer, not browsing (history entries kept).
    func resetToInitial() {
        history.resetToInitial()
        applyHistoryCursor()
        status = client.isRunning ? "Runtime warm (\(config.backend.rawValue))" : "Ready"
        clarifyChoices = []
        isBusy = false
    }

    func historyUp() {
        guard !isBusy, history.moveUp() else { return }
        applyHistoryCursor()
    }

    func historyDown() {
        guard !isBusy, history.moveDown() else { return }
        applyHistoryCursor()
    }

    func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBusy else { return }
        ensureRuntime()
        lastSubmittedPrompt = text
        draft = ""
        reply = ""
        isBusy = true
        status = "Thinking…"
        clarifyChoices = []
        let client = self.client
        Task.detached(priority: .userInitiated) {
            do {
                let outcome = try client.turn(user: text) { name, args in
                    DispatchQueue.main.sync {
                        MacHostToolRunner.execute(name: name, arguments: args)
                    }
                }
                await MainActor.run {
                    self.apply(outcome, prompt: text)
                    self.isBusy = false
                }
            } catch {
                await MainActor.run {
                    self.reply = ""
                    self.status = "Error: \(error)"
                    self.isBusy = false
                }
            }
        }
    }

    private func apply(_ outcome: TurnOutcome, prompt: String) {
        reply = outcome.replyText
        status = "Done"
        clarifyChoices = []
        for event in outcome.events {
            if case let .clarify(_, choices) = event {
                clarifyChoices = choices
                status = "Clarify"
            }
        }
        draft = ""
        lastSubmittedPrompt = prompt
        // Record text replies into history; clarify-only still records prompt + reply text.
        history.record(OverlayTurn(prompt: prompt, reply: outcome.replyText))
        applyHistoryCursor()
    }

    private func applyHistoryCursor() {
        if let turn = history.current {
            // History prompt is real editable draft text, not a faint placeholder.
            draft = turn.prompt
            lastSubmittedPrompt = ""
            reply = turn.reply
            status = "Done"
            clarifyChoices = []
        } else {
            lastSubmittedPrompt = ""
            reply = ""
            draft = ""
            clarifyChoices = []
        }
    }
}
