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

On macOS 27 with Apple Intelligence available, a loco-bot build with the
external inference backend can use the system model via `LOCO_BACKEND=fm`:

```bash
LOCO_BACKEND=fm ./scripts/run-overlay.sh
```

This selects `loco serve --backend external` and passes the bundled
`LocoFMAdapter` executable through `LOCO_INFERENCE_COMMAND`. Memory, topic notes,
and tool control stay in loco-bot. The adapter runs `fm count-tokens` and
`fm respond --no-stream --greedy --schema` on demand; it does not start an `fm serve` daemon.

The adapter counts the assembled conversation, instructions, and a textual
estimate of the schema before each generation, including tool continuations.
It keeps at most 10 user-turn groups and removes oldest groups until they fit.
The current prompt/tool exchange is never silently truncated; oversized input
returns an error. Persisted loco-bot memory is unaffected.

`LOCO_FM_CONTEXT_TOKENS` controls the total budget (conservative default: 4096;
1024 reserved for output/framing). Only raise it after checking the model's
context size. Schema token accounting is approximate, so generation may still
reach the framework's limit; errors are reported without automatic retries.
`LOCO_FM_PATH` overrides `/usr/bin/fm`, and `LOCO_FM_ADAPTER_PATH` overrides the
bundled adapter path. Each fm subprocess has a 45-second timeout, with a
100-second total adapter budget. Responses are buffered and validated before
returning text or one tool request to loco-bot.

To test without opening the overlay (use an isolated `--cache-dir` if desired):

```bash
swift build --product LocoFMAdapter
LOCO_INFERENCE_COMMAND="$PWD/.build/debug/LocoFMAdapter" \
  ../loco-bot/target/debug/loco chat --backend external --no-topic --no-tools 'こんにちは'
```

`fm available` must report the system model available. The adapter executable
speaks [loco-bot's external inference protocol](https://github.com/penta2himajin/loco-bot/blob/main/docs/external-inference.md).

## Layout

```
Sources/LocoMacOSCore/  # TurnOutcome, LocoServeClient (SwiftUI-free)
Sources/LocoMacOS/      # Overlay UI, hotkey, menu bar
Tests/LocoMacOSCoreTests/
docs/                   # handoff / i18n + local notes
```

## License

MIT. See `LICENSE`. loco-bot itself is MIT OR Apache-2.0; model weights are separate.
