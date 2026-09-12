---
name: explain
description: Map how something works in this project — use whenever asked how X works, to walk through Y, where Z happens, what happens when W, or to explain a flow, module, feature or subsystem in the codebase
---

Answer with a **map**, not a walkthrough.

This is the one skill without `disable-model-invocation`. It changes the shape of an
answer, never the repository, so there is nothing to protect against it firing on its
own — and the question it answers is almost never phrased as `/explain`.

## 1. Explore with a subagent

Dispatch a read-only subagent. The main context should receive the conclusion, not the
files it was drawn from.

Ask it for exactly this:

  * the **entry point** and the **exit point** — where the thing starts and where it ends
  * the components on the **happy path**, each anchored to a file, and a symbol where one
    exists
  * **edge-case behaviour found in the code**: retries, timeouts, ordering guarantees,
    caching, failure handling
  * anything **non-obvious, duplicated, dead, or contradicting** the docs or comments
    around it

Findings come from the code. A subagent that reports what the comments claim has
answered a different question.

## 2. Reply in this shape, under 30 lines

    <X> in one sentence: what it does and where it starts and ends.

    Flow:
      Trigger ──► ComponentA (file.swift) ──► ComponentB (file.swift) ──► Outcome
                        │
                        └─► side path (when / where)

    Pieces:
      ComponentA   file.swift       <one line: its single responsibility>

    Rules:
      - <behaviour not visible from the flow>

    Surprises:
      - <non-obvious / duplicated / dead / contradicting its own docs>

`Pieces` is three to six rows. **If it takes more, X is two topics** — say so, name both,
pick one, and offer the other.

`Rules` is three to five bullets. `Surprises` is omitted when there are none; it is not
padded with observations that are merely true.

## 3. Constraints

**The diagram is the happy path only.** Retries, timeouts and failure branches go to
`Rules`. A diagram that shows every branch is the code, redrawn worse.

**Every component is anchored to a file.** An unanchored box is a guess the reader cannot
check.

**Never quote code beyond one line.** The map points at the code; it does not reproduce
it.

**Depth on request.** "Expand ComponentB", "show the failure path" — answer those when
asked, not pre-emptively.

**A small question gets a small answer.** "Where is the token stored?" is one line with
an anchor and no template. The shape above is for a system, not for a lookup.

## Why a map

I ask this to build a mental model **before** reading the code, not instead of it. A map
with anchors survives the next refactor and tells me where to look; a walkthrough is
prose that duplicates the code, goes stale the moment either changes, and is believed
anyway.
