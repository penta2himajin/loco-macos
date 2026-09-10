import Testing
import LocoMacOSCore

@Suite("Overlay hotkey visibility")
struct OverlayHotkeyPolicyTests {
    @Test func hotkeyWhileHiddenShowsFreshComposer() {
        #expect(OverlayHotkeyPolicy.action(isVisible: false) == .showFresh)
    }

    @Test func hotkeyWhileVisibleDismissesLikeSpotlight() {
        // Esc already dismisses; ⌃⌘Space must also hide when the panel is up.
        #expect(OverlayHotkeyPolicy.action(isVisible: true) == .dismiss)
    }
}
