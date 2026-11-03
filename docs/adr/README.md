# Architecture Decision Records

ADRs capture significant architecture decisions and the reasoning behind them,
so later contributors can see why something is the way it is.

## File naming

`docs/adr/NNNN-title.md`: a zero-padded, sequential four-digit number, then a short
lowercase kebab-case title (for example `0001-record-architecture-decisions.md`).
Numbers are never reused or renumbered.

## Sections

Each ADR has a title heading (`# NNNN. Title`) followed by:

- **Context**: the problem, constraints and forces at play, including any measurements.
- **Decision**: what we chose, stated in full sentences ("We will ...").
- **Consequences**: what becomes easier or harder, and any follow-up work.

## Changing a decision

Do not rewrite an accepted ADR. Add a new one that supersedes it and note this in both.
