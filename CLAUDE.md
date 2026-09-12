# CLAUDE.md

Global guidance, true regardless of project and machine. A project's own `CLAUDE.md`
overrides anything here.

## Reading files

**Read files with the Read tool, not `cat`/`sed`/`head`.** Path-scoped rules attach to a
file when it is opened with Read; a file paged in through Bash arrives without them.

If a project has a `.claude/rules/` directory, its rules govern parts of that tree and
arrive with the files they govern — there is no need to read them up front.

## Documents of record

If a project keeps documents of record — a state or decision log, a how-to-run document,
a known-defects list — read them at the start of a session.

**A behaviour change updates them in the same commit as the change.** Never leave a
document describing behaviour that no longer exists.

Record only what cannot be recovered by reading the repository: the decision and why it
went that way, what was tried, what was rejected. Not what the code does.

## Context hygiene

Context is a budget, not a scratchpad. Everything in it is re-read on every turn, and a
fact that arrived two hundred messages ago competes with the instruction that arrived
last.

**One session, one task.** `/handoff` and then `/clear` between tasks. Carrying a
finished task into the next one keeps its dead ends in play, and they get argued with
again.

**Exploration goes to a subagent.** Grepping the repository, reading logs, "understand
module X" — dispatch it and keep the conclusion, not the file dumps. The main context
should hold what was decided, not what was looked at on the way.

**Never paste a log or a dump whole.** Read files with Read, in ranges. A file read in
full because its interesting part had not been located yet costs the same as one read on
purpose, and buries it.

**`/compact` deliberately, at a milestone** — the plan is agreed, before implementation
starts — and not in the middle of the work. Compaction mid-task summarises away the
detail the task is currently made of.

## Reporting

Pick the report size by what happened, not by how long it took.

**Small** — one place changed, no new component, no decision I did not ask for
(padding, a rename, a typo, a flag flipped). One or two sentences. No template.

    Padding on ProfileHeader is 16 now; nothing else touched.

**Medium** — a feature or fix that adds behaviour, or anything where you decided
something on your own. This shape:

    Done: <feature or fix in one line>
      - <capability 1>
      - <capability 2>
    Flow: <ComponentA -> ComponentB -> ComponentC>, <pattern used>
    Decided on my own: <things not discussed that I chose, assumed or worked around>
    Noticed: <findings unrelated to the task, one line each>

Each section one to three lines. Omit an empty section rather than writing "none".

**Large** — several independent parts (a feature spanning modules, a migration, a
refactor plus a fix). One line naming the parts, then the medium shape once per part,
then a single "Noticed" at the end. Do not merge parts: the point is that each part has
its own "Decided on my own".

**When unsure between small and medium, ask: did I decide anything?** If yes, medium.

**"Decided on my own" is the section that matters most.** Anything not agreed goes
there, however small — it is the input for `DECISIONS.md`.

Nothing else, at any size: no restating the diff, no describing how the answer was
found, no file contents "in case", no recap of earlier turns. Details, reasoning and
evidence on request — "why", "show me", "what did you check" — and only then.

**Between tool calls, say nothing** unless a decision is needed.

Every line of output is re-read on every later turn, and output tokens cost several
times what input does. A paragraph explaining what `git diff` already shows is paid for
until `/clear`, and it buries the one line — an unagreed decision — that actually needs
attention.

## Tests

**Reproduce a defect with a failing test first, and prove it fails against the OLD
behaviour** — revert the fix, or express the old behaviour in place, and watch the new
test go red. A test written after the fix proves only that the code does what it does.

## Branches and commits

Work on a branch off the default branch; when it is green, fast-forward the default
branch onto it and push both.

Verify a series commit by commit:

    git rebase --exec "<test command> > /dev/null" <base>

Redirect rather than pipe: a pipeline returns the exit code of its last stage, so a
failing test will not stop the rebase.

Commit messages are one imperative sentence about what changed, then the reasoning that
would otherwise be lost — what was tried, what was rejected, why. Read `git log` before
writing one.
