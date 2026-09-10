# loco-macos

## Overview

Thin macOS surface for loco-bot: Spotlight-like overlay (⌃⌘Space), menu-bar helper,
and a warm `loco serve` child process. Inference, memory, S1, and tools stay in
**loco-bot**; this repo is UI + IPC only.

Behaviour contract: [loco-bot `docs/macos-overlay.md`](https://github.com/penta2himajin/loco-bot/blob/main/docs/macos-overlay.md).

## Project Structure

```
Sources/LocoMacOSCore/   # Agent JSON types + LocoServeClient
Sources/LocoMacOS/       # AppKit/SwiftUI overlay + hotkey
Tests/LocoMacOSCoreTests/
docs/                    # handoff, i18n, local notes
git-hooks/               # pre-push (swift build)
```

## Development Setup

```bash
git config core.hooksPath git-hooks
# Requires a built `loco` from loco-bot on PATH (or default debug path).
```

## Build & Test

```bash
swift test
swift build
```

Do **not** run GPU-backed `loco serve` smoke tests while other Metal/MLX jobs
are active on the machine; default config uses `--backend cpu`.

## Development Principles

- TDD for Core (JSON / config / client seams).
- Overlay stays a thin client of `TurnOutcome` / `AgentEvent`.

## Architectural Boundaries

- No LiteRT-LM / model weights in this repo.
- No Android/glasses code here.
- Core target must stay SwiftUI-free.

## Prohibitions

1. Do not spawn `loco serve --backend gpu` in CI or default tests.
2. Do not steal Spotlight’s `⌘Space` as the default hotkey.
3. Do not vendor loco-bot sources; depend on the `loco` binary / future IPC.

## Git Conventions

- Conventional Commits; agent trailer when an AI authors the commit.
- Branch prefix: `claude/<topic>`, `codex/<topic>`, or `human/<topic>`.

## Session Handoff

See `docs/handoff-protocol.md`. Label: `session-handoff`.

## Internationalisation

See `docs/i18n-policy.md` if a Japanese README is added.

---

<!-- Common rules below this line apply to every project. -->

## Common Development Rules

### TDD (Red → Green → Refactor)

All implementation work proceeds in this cycle:

1. **Red**: write a failing test that captures the intended behaviour.
2. **Green**: write the minimum code that makes the test pass.
3. **Refactor**: tidy up while keeping tests green.

When a test fails, fix the production code — do not delete, skip, or weaken the test.

### Measure, Don't Conjecture

Base decisions on observed data, not assumptions. Before optimising, claiming a bottleneck, or asserting that something is slow or broken, measure it — profile, benchmark, log, or reproduce. When you report a cause, cite the measurement that supports it.

### Git Conventions

- **Conventional Commits**: `feat:` `fix:` `docs:` `refactor:` `test:` `ci:` `chore:`.
- **Branch naming**: `claude/<topic>`, `codex/<topic>`, or `human/<topic>`.
- **Trailer**: when an AI agent authors the commit, append a trailer crediting the agent.
- **Pre-push hook**: `git config core.hooksPath git-hooks`.

### Pull Requests

- **Always ready for review.** Open PRs in the "ready" state, never as drafts.
- **Auto-subscribe after creating a PR.** Immediately after the PR is created, subscribe to its activity without asking the user.
- **One PR per workstream**, matching the handoff issue.

### Common Prohibitions

1. Do not delete, skip, or comment out existing tests.
2. Do not modify CI configuration without explicit instruction.
3. Do not weaken production code merely to make tests pass.
4. Do not commit credentials, API keys, signed URLs, or anything in `.env*`.
