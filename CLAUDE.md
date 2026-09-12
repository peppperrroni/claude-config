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

## Output

Size the report by what happened, not by effort. Test: did I decide anything? If yes,
at least medium.

**Small** — one place changed, no new component, nothing decided. One or two sentences.

**Medium** — new behaviour, or any decision of yours I did not ask for:

    Done: <one line>
      - <capability> ...
    Flow: <ComponentA -> ComponentB -> ComponentC>, <pattern>
    Decided on my own: <anything not agreed, however small — feeds DECISIONS.md>
    Noticed: <findings unrelated to the task>

One to three lines per section; drop empty sections.

**Large** — several independent parts: name them, then medium once per part, one
"Noticed" at the end.

No restating the diff, no describing the search, no file contents "in case", no recap.
Details on request only. Between tool calls, say nothing unless you need a decision.

Why: output is re-read every turn and costs more than input; narration buries the one
line that needs my attention.

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
