import Testing
import LocoMacOSCore

@Suite("Overlay history navigator")
struct OverlayHistoryNavigatorTests {
    @Test func hotkeyResetLeavesLiveEmptyEvenAfterReply() {
        var nav = OverlayHistoryNavigator()
        nav.record(OverlayTurn(prompt: "q1", reply: "a1"))
        #expect(!nav.isLive)
        #expect(nav.current?.prompt == "q1")

        nav.resetToInitial()
        #expect(nav.isLive)
        #expect(nav.current == nil)
    }

    @Test func upFromLiveShowsNewestThenOlder() {
        var nav = OverlayHistoryNavigator()
        nav.record(OverlayTurn(prompt: "older", reply: "a0"))
        nav.record(OverlayTurn(prompt: "newer", reply: "a1"))
        nav.resetToInitial()

        let toNewest = nav.moveUp()
        #expect(toNewest)
        #expect(nav.current?.prompt == "newer")
        let toOlder = nav.moveUp()
        #expect(toOlder)
        #expect(nav.current?.prompt == "older")
        let atOldest = nav.moveUp()
        #expect(!atOldest)
        #expect(nav.current?.prompt == "older")
    }

    @Test func downFromNewestReturnsToInitial() {
        var nav = OverlayHistoryNavigator()
        nav.record(OverlayTurn(prompt: "q1", reply: "a1"))
        nav.record(OverlayTurn(prompt: "q2", reply: "a2"))
        // After record we sit on newest; one ↓ → live/initial.
        #expect(nav.current?.prompt == "q2")
        let toLive = nav.moveDown()
        #expect(toLive)
        #expect(nav.isLive)
        let stayLive = nav.moveDown()
        #expect(!stayLive)
    }

    @Test func downWalksTowardNewerThenInitial() {
        var nav = OverlayHistoryNavigator()
        nav.record(OverlayTurn(prompt: "q1", reply: "a1"))
        nav.record(OverlayTurn(prompt: "q2", reply: "a2"))
        nav.resetToInitial()
        _ = nav.moveUp()
        _ = nav.moveUp()
        #expect(nav.current?.prompt == "q1")

        let toQ2 = nav.moveDown()
        #expect(toQ2)
        #expect(nav.current?.prompt == "q2")
        let toLive = nav.moveDown()
        #expect(toLive)
        #expect(nav.isLive)
    }

    @Test func upWithEmptyHistoryIsNoOp() {
        var nav = OverlayHistoryNavigator()
        let moved = nav.moveUp()
        #expect(!moved)
        #expect(nav.isLive)
    }

    @Test func browsingUsesPromptAsEditableDraftNotPlaceholder() {
        // UI contract: when current != nil, draft = prompt and lastSubmitted stays empty.
        var nav = OverlayHistoryNavigator()
        nav.record(OverlayTurn(prompt: "地下鉄について", reply: "便利です"))
        nav.resetToInitial()
        _ = nav.moveUp()
        #expect(nav.current?.prompt == "地下鉄について")
        #expect(nav.current?.reply == "便利です")
        #expect(!nav.isLive)
    }
}
