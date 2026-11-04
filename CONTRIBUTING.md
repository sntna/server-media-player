# Contributing

Thanks for helping out. This page is the quick entry point for humans and agents.
[AGENTS.md](AGENTS.md) is the source of truth for the rules below; if the two ever disagree,
`AGENTS.md` wins. For what the project is, see [README.md](README.md).

## Running the checks

```
./scripts/check.sh
```

This is the one command that must pass before a PR. CI (`.github/workflows/ci.yml`) runs the same
script on pull requests and on pushes to `main`, so a green local run is what CI will see.

Rust checks (`cargo fmt`, `clippy`, `test`) are skipped until `core/` exists. Until then a passing
run prints `check.sh: ok`.

## Branches and pull requests

- Name your branch `factory/<issue-number>-<short-slug>`. Never commit to `main`.
- Keep changes small and scoped to the issue. No drive-by refactors.
- Write commit messages in the imperative mood, saying what changed and why.
- Open a PR whose body contains `Closes #<issue>`. Do not merge your own PR.
- Do not touch `.github/`, CI config, lockfiles or `*.env*` unless the issue explicitly says so.
- Never commit secrets, tokens, server URLs with credentials or personal media paths. Test fixtures
  must be synthetic.

## Filing issues

The issue is the spec, so a good one saves everyone a round trip. See
[docs/filing-issues.md](docs/filing-issues.md) for what to include, how `goal` issues differ from ready
tasks, what the labels mean, and what to do when an issue gets `needs-info`.

## tvOS code

The automation runs on Ubuntu without Xcode, so code under `platform/tvos/` cannot be built there.
Keep such changes small and mechanical, state in the PR what was not compiled, and rely on the macOS
CI job to verify it.
