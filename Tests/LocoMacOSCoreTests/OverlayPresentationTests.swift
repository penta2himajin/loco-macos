import Testing
import CoreGraphics
import LocoMacOSCore

@Suite("Overlay presentation / panel resize")
struct OverlayPresentationTests {
    @Test func searchOnlyDoesNotShowBody() {
        let p = OverlayPresentation(reply: "", clarifyCount: 0, status: "Thinking…")
        #expect(!p.showsBody)
        #expect(p.preferredPanelSize.height == OverlayPresentation.searchOnlyHeight)
    }

    @Test func replyRequiresExpandedPanelTallerThanSearchOnly() {
        // Reproduces the “reply invisible until reopen” bug class: after a turn
        // completes, preferred height must grow so the NSPanel can show the body.
        let before = OverlayPresentation(reply: "", status: "Thinking…")
        let after = OverlayPresentation(
            reply: "地下鉄は便利ですが、ラッシュ時は混雑します。",
            status: "Done"
        )
        #expect(!before.showsBody)
        #expect(after.showsBody)
        #expect(after.preferredPanelSize.height > before.preferredPanelSize.height)
        #expect(after.preferredPanelSize.height > OverlayPresentation.searchOnlyHeight)
    }

    @Test func frameControllerResizesWhenReplyArrives() {
        var frame = PanelFrameController()
        let idle = OverlayPresentation()
        let idleChanged = frame.apply(idle)
        #expect(!idleChanged)
        #expect(frame.contentSize.height == OverlayPresentation.searchOnlyHeight)

        let withReply = OverlayPresentation(reply: "hello from loco", status: "Done")
        let changed = frame.apply(withReply)
        #expect(changed)
        #expect(frame.contentSize.height > OverlayPresentation.searchOnlyHeight)
    }

    @Test func reopenAppliesSameExpandedSize() {
        // Closing/reopening worked because showOverlay re-applied size; applying
        // twice must keep the expanded height (idempotent).
        var frame = PanelFrameController()
        let presentation = OverlayPresentation(reply: "visible answer", status: "Done")
        let first = frame.apply(presentation)
        #expect(first)
        let height = frame.contentSize.height
        let second = frame.apply(presentation)
        #expect(!second)
        #expect(frame.contentSize.height == height)
    }
}

@Suite("Composer key chord")
struct ComposerKeyChordTests {
    @Test func shiftReturnInsertsNewlineInsteadOfSubmit() {
        #expect(ComposerKeyChord.action(returnWithShift: true) == .insertNewline)
        #expect(ComposerKeyChord.action(returnWithShift: false) == .submit)
    }
}

@Suite("Reply viewport")
struct ReplyLayoutTests {
    @Test func shortReplyFitsWithoutScroll() {
        let text = (1...5).map { "line \($0)" }.joined(separator: "\n")
        #expect(ReplyLayout.lineCount(for: text) == 5)
        #expect(!ReplyLayout.needsScroll(for: text))
        #expect(ReplyLayout.viewportHeight(for: text) == 5 * ReplyLayout.lineHeight)
    }

    @Test func longReplyCapsVisibleHeightAtFifteenLines() {
        let text = (1...20).map { "line \($0)" }.joined(separator: "\n")
        #expect(ReplyLayout.lineCount(for: text) == 20)
        #expect(ReplyLayout.needsScroll(for: text))
        #expect(ReplyLayout.viewportHeight(for: text) == ReplyLayout.maxViewportHeight)
        #expect(ReplyLayout.maxVisibleLines == 15)
    }

    @Test func preferredHeightMatchesViewportCapConsistently() {
        // First-arrival vs reopen must prefer the same height (no “scroll then no-scroll”).
        let short = OverlayPresentation(reply: "one short line", status: "Done")
        let long = OverlayPresentation(
            reply: (1...20).map { "長い返答の行 \($0)" }.joined(separator: "\n"),
            status: "Done"
        )
        let shortReply = ReplyLayout.viewportHeight(for: short.reply)
        let longReply = ReplyLayout.viewportHeight(for: long.reply)
        #expect(short.preferredPanelSize.height == OverlayPresentation.searchOnlyHeight + 1 + 22 + shortReply)
        #expect(long.preferredPanelSize.height == OverlayPresentation.searchOnlyHeight + 1 + 22 + longReply)
        #expect(longReply == ReplyLayout.maxViewportHeight)
        #expect(short.preferredPanelSize.height < long.preferredPanelSize.height)
    }
}

@Suite("Composer placeholder")
struct ComposerPlaceholderTests {
    @Test func showsLastSubmittedWhenDraftCleared() {
        #expect(
            ComposerPlaceholder.text(draft: "", lastSubmitted: "地下鉄について教えて")
                == "地下鉄について教えて"
        )
    }

    @Test func idleWhenNoSubmissionYet() {
        #expect(ComposerPlaceholder.text(draft: "", lastSubmitted: "") == ComposerPlaceholder.idle)
    }

    @Test func idleWhileTypingEvenIfLastSubmittedExists() {
        #expect(
            ComposerPlaceholder.text(draft: "次の質問", lastSubmitted: "前の質問")
                == ComposerPlaceholder.idle
        )
    }
}
