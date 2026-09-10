# loco-macos

macOS companion overlay for [loco-bot](https://github.com/penta2himajin/loco-bot): global hotkey
(**⌃⌘Space**) → floating panel → `loco serve` JSONL → reply.

To **override** the system emoji / Character Viewer on the same chord, grant **Accessibility** to `LocoMacOS` (menu bar → *Enable Accessibility for ⌃⌘Space…*).

Behaviour SoT (lives in loco-bot):  
https://github.com/penta2himajin/loco-bot/blob/main/docs/macos-overlay.md

## Setup

```bash
git config core.hooksPath git-hooks

# loco-bot must provide the `loco` binary (PATH or ~/repos/loco-bot/target/debug/loco)
cd ../loco-bot && cargo build -p loco-cli
```

## Build & test

```bash
swift test          # core JSON / config tests (no GPU)
./scripts/run-overlay.sh   # build .app and open (menu bar attaches correctly)
```

Prefer `./scripts/run-overlay.sh` over raw `swift run` — launching from an IDE/agent
shell often fails to show the `NSStatusItem` on the interactive menu bar.

Default runtime backend is **cpu** so this overlay does not fight other GPU jobs.
Switch to gpu in Settings later (see SoT) when the machine is free.

## Layout

```
Sources/LocoMacOSCore/  # TurnOutcome, LocoServeClient (SwiftUI-free)
Sources/LocoMacOS/      # Overlay UI, hotkey, menu bar
Tests/LocoMacOSCoreTests/
docs/                   # handoff / i18n + local notes
```

## License

MIT. See `LICENSE`. loco-bot itself is MIT OR Apache-2.0; model weights are separate.
