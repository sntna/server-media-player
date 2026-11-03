#!/usr/bin/env bash
# The one command that must pass before any PR. Runs whatever exists; grows with the repo.
set -euo pipefail
cd "$(dirname "$0")/.."

for f in AGENTS.md CLAUDE.md README.md; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

if [ -f core/Cargo.toml ]; then
  (cd core && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test)
else
  echo "core/ not created yet: skipping Rust checks"
fi

# Test hook for the factory e2e suite: fail on CI (not locally) when the marker file exists.
if [ -n "${GITHUB_ACTIONS:-}" ] && [ -f ci-fail-marker ]; then
  echo "CI-only failure: ci-fail-marker present" >&2
  exit 1
fi

echo "check.sh: ok"
