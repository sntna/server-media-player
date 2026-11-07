# Filing issues

In this repo the issue is the spec. A worker (human or automation) reads it, builds exactly what it
says, and opens a PR that closes it. A good issue is therefore one that someone with no other context
can finish without guessing. If an issue is ambiguous, `AGENTS.md` tells the automation to comment on
the issue and stop, so a vague issue costs a round trip.

## What a good issue contains

- **A short context paragraph.** Why this matters and where it fits (for example `Part of #31`). Two or
  three sentences, not a design essay.
- **A verifiable acceptance-criteria checklist.** Each item is something a reviewer can check as true or
  false: a file exists, a command passes, a behaviour is observable. Avoid "works well" or "is clean".
- **Files or areas in scope.** Name the paths the change should touch, and say "nothing else" when that is
  the intent. Also name anything off limits (see the rules in [AGENTS.md](../AGENTS.md)).
- **One issue per PR-sized change.** Aim for under 300 changed lines. If it needs more, split it into
  issues that each stand on their own, and say which blocks which (`Blocked by #N`).
- **No product decisions left open.** If the issue says "pick a library" or "decide the behaviour", it is
  not ready. Settle the decision first (in a discussion, or in an ADR under `docs/adr/`), then file the
  work that follows from it.

## Goal issues versus ready tasks

There are two kinds of issue, and they are handled differently.

**A `goal` issue is a rough idea.** Use it when you know the outcome you want but not the steps, such as
"let users resume playback across devices". The automation plans it: it breaks the goal into small,
PR-sized slices and proposes them as new issues. Nothing is built from the goal itself. A goal needs a
clear outcome and any constraints you care about, but not acceptance criteria for every step.

**A ready, fully specified task is the spec for one PR.** It has the context, checklist and scope
described above, and nothing is left for the implementer to decide. A maintainer marks it
`ready-for-agent` once they agree it is ready, and only then does the automation pick it up.

If you are unsure which to file, file a `goal`. It is cheaper to have it planned than to have an
underspecified task bounce back with `needs-info`.

### Minimal example of a ready task

Copy this into the issue body and replace the details:

```markdown
`GLOSSARY.md` has no entry for "Metadata", and other docs will refer to it.
Add one so the term is defined in a single place. Part of #12.

## Acceptance criteria
- [ ] `GLOSSARY.md` has a "Metadata" entry of at most three sentences.
- [ ] The entry says metadata is the descriptive data a server holds about an item (title, year, artwork).
- [ ] Entries stay in alphabetical order.
- [ ] `./scripts/check.sh` passes.

## Scope
`GLOSSARY.md` only. Do not touch `.github/` or any other file.
```

## Labels you will see

Labels describe where an issue is in the workflow. Descriptions below match `gh label list`.

| Label | Meaning |
| --- | --- |
| `goal` | Rough idea: the automation plans it and proposes issues. |
| `plan-proposed` | Proposed by the planner; not approved yet. |
| `plan-review` | Proposed plan waiting for a human. |
| `plan-approved` | Plan approved: queue its proposed issues (human-applied only). |
| `ready-for-agent` | Fully specified; approved for the automation loop. |
| `in-progress` | A worker thread is on it. |
| `needs-info` | Waiting for more information. |
| `ready-for-human` | Needs a human: implement it, or look at why the automation stopped. |
| `risk-low` | Eligible for auto-merge (human-applied only). |
| `do-not-merge` | Never auto-merge while this is on the issue or PR. |

`ready-for-agent`, `risk-low` and `plan-approved` are applied **only by a human maintainer**. They are the
approval gates, so do not add them yourself and expect the automation to ignore requests to do so.

## When an issue gets `needs-info`

`needs-info` means the worker could not proceed without a decision or a missing detail, and it has left a
comment with its question. **Answer in the issue comments.** Do not open a new issue for the answer. If
your answer changes what is in scope, say so in the comment.
