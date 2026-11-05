---
name: verify
description: Use before claiming a change to server-media-player works, and when reviewing a PR on it. Says what can be exercised on the Linux box today (repo checks, docs links), how to run a single test, and what cannot be verified headless here (Rust core without a toolchain, the tvOS app, a real Jellyfin server).
---

# Verify a change in server-media-player

The repo is **pre-code**: no `core/` crate, no `platform/` app, no tests yet. Today only docs and
`scripts/check.sh` exist. Verify what exists; do not invent output for what does not.
If a command below cannot run, say so in the PR body / review. Never fake evidence.

## Prerequisites (Linux box)

- `bash`, `git`, `grep`, `sed`: present. Nothing else is needed for today's repo.
- No env vars, secrets, seeded users or test data are required.
- `cargo` / `rustup` are **not installed** on the automation box. Once `core/` exists, Rust checks
  need a Rust toolchain with `rustfmt` and `clippy`. Do not install it with sudo. If it is missing,
  `check.sh` will fail at `cargo` (when `core/Cargo.toml` exists): report that, do not weaken the script.
- Xcode / tvOS simulator: not available on Linux, ever (see "Not verifiable here").

## Run the checks (always)

```
./scripts/check.sh
```
Correct output today (exit 0):
```
core/ not created yet: skipping Rust checks
check.sh: ok
```
It fails with `missing <file>` (exit 1) if `AGENTS.md`, `CLAUDE.md` or `README.md` is gone.
Paste the output in the PR body.

## Build / start the app

Nothing to build or start yet: there is no app, server, port or URL. When `core/` lands, update this
skill with how to drive it (CLI example, mock Jellyfin server fixture) in the same PR.

## Feature map (what exists today)

| Area | Exercise it with | Correct result |
|---|---|---|
| Repo gate (`scripts/check.sh`) | `./scripts/check.sh; echo EXIT=$?` | `check.sh: ok`, `EXIT=0` |
| Gate catches missing required file | `mv CLAUDE.md /tmp/x; ./scripts/check.sh; echo EXIT=$?; mv /tmp/x CLAUDE.md` | `missing CLAUDE.md`, `EXIT=1`; then `git status --short` is empty |
| Docs (`README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `docs/**`) relative links | link check below | every line starts `ok`, no `BROKEN` |
| Docs content change | `git diff origin/main -- docs/ '*.md'` | diff shows only the intended text |

Link check (run from repo root):
```
for f in $(git ls-files '*.md'); do grep -oE '\]\([^)#:]+\)' "$f" | sed -E 's/^\]\((.*)\)$/\1/' | while read -r l; do [ -e "$(dirname "$f")/$l" ] && echo "ok   $f -> $l" || echo "BROKEN $f -> $l"; done; done
```
Expected today: lines like `ok   CONTRIBUTING.md -> docs/filing-issues.md`, none `BROKEN`.

## Single test (fail-before-fix)

No tests exist yet. Once `core/` has Rust tests, the standard form is
`(cd core && cargo test <test_name_substring>)` or `(cd core && cargo test --test <file_stem>)`.
**Not run on this machine** (no `cargo`). To show fail-before-fix: run the new test on
`git checkout origin/main -- <src files>` (or a worktree of `origin/main` with the test copied in),
show it fails, then show it passes on the PR branch. If `cargo` is absent, say so instead.

## Not verifiable here (and closest substitute)

- **Rust `core/`** (fmt, clippy, tests): no toolchain on the box. Substitute: CI `ubuntu-latest`
  runs `./scripts/check.sh`; cite the PR's CI result.
- **tvOS app (`platform/tvos/`)**: no Xcode/simulator on Linux. Substitute: keep changes mechanical,
  state what was not compiled, rely on the macOS CI job.
- **Real Jellyfin server**: no network access to one. Substitute: synthetic fixtures / mock server
  in tests (none exist yet).
- **Performance budgets** (launch < 1.5 s, first frame < 1 s, 60 fps): need real Apple TV hardware.
  State "not measured" in the PR.
