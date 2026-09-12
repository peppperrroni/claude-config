---
name: handoff
description: Record the state of the project at the end of a working session
disable-model-invocation: true
---

Update this project's documents of record so they match what this session actually did.

## 1. Find the documents

Read the project's `CLAUDE.md` first. If it names documents of record, those are the
ones — use them and skip the search.

Otherwise look in the repository root and in `docs/` for the three usual shapes:

  * a state or decision log — `STATE.md`, `DECISIONS.md`, `ARCHITECTURE.md`, an
    `adr/` or `decisions/` directory
  * a how-to-run / what-is-verified document — `RUNNING.md`, `CONTRIBUTING.md`, or the
    relevant sections of `README.md`
  * a known-defects list — `FOLLOW-UPS.md`, `KNOWN-ISSUES.md`, `TODO.md`

A project may have one, two, or none of these. If there is nothing of the kind, say so
and stop. Do not create a document that the project never asked for.

## 2. Find out what really changed

Read `git diff` and `git log` for the session. Work from what the repository shows, not
from recollection of what was attempted.

## 3. Update the state log

Where the work stopped, and what is next. If a decision was made, record it with the
date and the reasoning — why this way and not another way.

Match the headings the document already uses. Do not impose a new structure on it.

## 4. Update the how-to-run document

Only if the way the project runs, or what counts as verified, actually changed.

## 5. Update the defects list

Only if a defect was found or closed.

## 6. Record what was decided without being asked

Scan this session's reports for **"Decided on my own"** items — the section the global
`CLAUDE.md` requires on every medium and large report. Each one is a decision that was
made rather than agreed, which is exactly what `DECISIONS.md` exists for.

An item is recorded when it is **still true in the final code**, and as "decision + why",
not as a description of the code.

Two exclusions, both of which override the instinct to be thorough:

  * **Reverted during the session — not recorded.** A decision that was replaced is not
    a decision the repository made; the last one standing is.
  * **Already in `DECISIONS.md` — not recorded again.** Append only what is new.

This does not relax the rule below. An item that was reported but never actually landed
in the code did not happen, and does not go in.

## 7. Show the diff

Show the diff of the documents. Do not commit.

## 8. Record that this ran

    # Windows
    powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\hooks\handoff-done.ps1"

    # macOS / Linux
    bash ~/.claude/hooks/handoff-done.sh

That stamps a marker the Stop hook reads, so it stops reminding that the tree is dirty
and handoff has not run. Skip it silently if the file is not there — the hooks are
optional and a missing one is not an error.

## Two rules that override the steps above

**Describe no code and no structure.** Record only what cannot be recovered by reading
the repository — a reader can see what the code does; they cannot see what it was
weighed against.

**Never write anything that did not happen in this session.** A plausible summary of
work that was not done is worse than no entry at all.
