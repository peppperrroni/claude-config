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
