---
name: resume
description: Read the state of the project back at the start of a working session
disable-model-invocation: true
---

Reconstruct where the last session stopped, from what the repository records rather than
from anything remembered. This skill reads; it changes nothing.

## 1. Find the documents

Read the project's `CLAUDE.md` first. If it names documents of record, those are the ones
— use them and skip the search.

Otherwise look in the repository root and in `docs/` for:

  * `STATE.md` — where the work stopped and what is next
  * `DECISIONS.md` — what was decided and why
  * `FOLLOW-UPS.md` — known defects and deferred work
  * `RUNNING.md` — how to build, run and verify

A project may have some of these or none. **If there is none, say so and stop.** Do not
create one, and do not reconstruct a session history from the commit log to fill the gap
— an absent state document is itself the finding, and the answer is `/handoff` at the end
of this session, not an invented summary at the start of it.

## 2. Read what the repository shows

    git status
    git log -10 --oneline

Uncommitted changes are the most reliable evidence of where work stopped: a document can
be stale, the working tree cannot.

## 3. Summarise

Three things, briefly:

  * **Where it stopped** — the last completed step, and whether the tree is clean.
  * **What is open** — unfinished work, unresolved decisions, known defects. Say which
    document each came from, so a stale claim can be traced.
  * **Where the documents and the tree disagree** — if `STATE.md` describes work that the
    log does not show, or the tree holds changes no document mentions, that gap is the
    most useful thing to report. Do not quietly reconcile it.

## 4. Propose one next step

**One.** The single thing to do first, and why it is first. Not a plan, not a list — a
list invites agreement without a decision.

Then stop and wait.

## Two rules that override the steps above

**Describe no code and no structure.** Record only what cannot be recovered by reading
the repository — a reader can see what the code does; they cannot see what it was weighed
against.

**Never say anything happened that the repository does not show.** A plausible account of
a session that went another way is worse than admitting the record is thin.
