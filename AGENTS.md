# AGENTS.md

Guidance for coding agents (and humans) working in this repo. `CLAUDE.md` imports this file; edit here.

## What this is

A **performance-first media player client for self-hosted media servers**, starting with **Jellyfin**,
shipping first on **Apple TV (tvOS)**, architected so every other major platform (Android TV, iOS/iPadOS,
macOS, Windows, Linux, web) can be added without rewriting the logic.

Non-goals for now: running a server, transcoding on-device, social features, a plugin system.

## Architecture (proposed; challenge it in an issue before deviating)

```
core/                 Rust crate, no UI, no OS-specific code. Single source of truth for behaviour.
                      Jellyfin API client, auth/session, library models, SQLite cache, playback
                      session reporting, track/subtitle selection, direct-play vs transcode decision.
bindings/             Generated FFI (UniFFI): Swift now, Kotlin next, C ABI for everything else.
platform/tvos/        Swift + SwiftUI app: UI, focus engine, Siri Remote, Top Shelf, PlayerEngine impl.
platform/<other>/     Added later; each is a thin shell over `core` + a PlayerEngine impl.
docs/                 Architecture notes and ADRs (docs/adr/NNNN-title.md).
scripts/check.sh      The one command that must pass before any PR.
```

Rules that keep it portable:
- **Logic lives in `core`.** A platform shell contains only UI, input handling and the native player glue.
  If you write a rule twice (in Swift and in Kotlin), it belongs in `core`.
- **The player is behind an interface** (`PlayerEngine`): load, play/pause, seek, tracks, stats, events.
  tvOS default is `AVPlayer` (VideoToolbox hardware decode, HDR/Dolby Vision where the OS allows).
  Containers/codecs AVPlayer cannot handle (e.g. MKV) need a second engine; the choice (libmpv vs
  VLCKit vs FFmpeg-based) is an **open decision**: settle it with a spike and an ADR before building on it.
- **Prefer direct play.** Transcode (server-side HLS) is the fallback, never the default.
- Jellyfin first, but keep the server behind a `MediaServer` trait so Emby/Plex-style backends are possible.

## Performance is the product

Budgets are targets to measure against, not guesses to ignore. Record measurements in the PR.
- Cold launch to interactive library grid: aim < 1.5 s on the oldest supported Apple TV.
- Play press to first frame (direct play, LAN): aim < 1 s.
- 60 fps scrolling in large libraries (10k+ items): virtualised lists, no work on the main thread
  that can be done elsewhere, no synchronous disk or network I/O on the UI thread.
- Images: request server-resized sizes that match the display, decode off-main-thread, cache on disk
  and in memory with bounded size.
- Memory: bounded caches, no unbounded growth during long sessions.
- Dependencies are a cost (binary size, startup, supply chain). Add one only with a reason in the PR.

## How to work here

1. Read the issue fully. It is the spec. If it is ambiguous or needs a product decision, **do not guess**:
   comment on the issue with `gh issue comment`, then stop. Never use interactive question tools;
   nobody is watching the thread live.
2. Branch: `factory/<issue-number>-<short-slug>`. Never commit to `main`.
3. Keep the change small and scoped to the issue. No drive-by refactors.
4. Run `./scripts/check.sh` and make it pass. Add or update tests for behaviour you change.
5. Commit with a clear message (imperative mood, what and why). No AI/tool attribution trailers.
6. Push the branch and open a PR whose body contains `Closes #<issue>`. Do **not** merge it.
7. Do not modify `.github/`, CI config, lockfiles, or anything named `*.env*` unless the issue explicitly says so.
8. Never commit secrets, tokens, server URLs with credentials, or personal media paths. Test fixtures must be synthetic.

## Environment limits (important for agents on the Linux box)

- The automation runs on **Ubuntu without Xcode**. You can build and test `core/` fully. You **cannot**
  build or run the tvOS app there. For `platform/tvos/` changes, keep them small and mechanical, state
  clearly in the PR what was not compiled, and rely on the macOS CI job to verify.
- No network access to a real Jellyfin server. Use recorded/synthetic fixtures and a mock server in tests.

## Code style

- Rust: `cargo fmt`, `cargo clippy -- -D warnings`, no `unsafe` without a comment explaining the invariant,
  errors via `thiserror`, async via `tokio` only at the edges.
- Swift: SwiftUI, Swift Concurrency, no force-unwraps in non-test code, UI state is derived from `core` state.
- Public items get doc comments that explain why, not what.
