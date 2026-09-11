# Local notes

Upstream behaviour SoT remains in loco-bot:

https://github.com/penta2himajin/loco-bot/blob/main/docs/macos-overlay.md

This repo implements that surface. Default backend for the helper is **cpu**
to avoid contending with other on-device GPU workloads. Override with
`LOCO_BACKEND=gpu` when measuring or when the machine is free.

## Host-executed tools (direction)

Host-executed (surface-owned) tools live in this surface, not in loco-bot:

1. Overlay **advertises** OpenAI-style schemas (`configure` / `ServeClientMessage`).
2. loco-bot runs the model loop; on a host tool call it returns `awaiting_tool`.
3. Overlay **executes** (v1 auto-runs `open_url` via NSWorkspace; medium/high
   inline allow/deny UI still TODO) and sends `tool_result`.

Portable tools (clock, notes, …) may remain `exec: local` inside loco-bot.
macOS v1 seed catalog: `MacHostTools` (`open_url`, …).

Requires a loco-bot build that understands `configure` / `awaiting_tool` /
`tool_result` (branch `claude/host-tool-serve` or later main).
