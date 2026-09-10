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

    var composerPlaceholder: String {
        ComposerPlaceholder.text(draft: draft, lastSubmitted: lastSubmittedPrompt)
    }

    private let client: LocoServeClient
    private let config: RuntimeConfig

    init(config: RuntimeConfig = .overlayDefault) {
        self.config = config
        self.client = LocoServeClient(config: config)
    }

    func ensureRuntime() {
        guard !client.isRunning else { return }
        do {
            try client.start()
            status = "Runtime warm (\(config.backend.rawValue))"
        } catch {
            status = "Runtime failed: \(error.localizedDescription). Is `loco` on PATH?"
        }
    }

    func stopRuntime() {
        client.stop()
        status = "Runtime stopped"
    }

    func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBusy else { return }
        ensureRuntime()
        lastSubmittedPrompt = text
        draft = ""
        isBusy = true
        status = "Thinking…"
        clarifyChoices = []
        let client = self.client
        Task.detached(priority: .userInitiated) {
            do {
                let outcome = try client.turn(user: text)
                await MainActor.run {
                    self.apply(outcome)
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

    private func apply(_ outcome: TurnOutcome) {
        reply = outcome.replyText
        status = "Done"
        for event in outcome.events {
            if case let .clarify(_, choices) = event {
                clarifyChoices = choices
                status = "Clarify"
            }
        }
        draft = ""
    }
}
