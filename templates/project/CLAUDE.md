# CLAUDE.md

<!-- Project-level guidance. Overrides ~/.claude/CLAUDE.md wherever the two disagree.
     Keep it short: everything here is paid for in every session of this project.
     Anything that is only occasionally relevant belongs in .claude/rules/ instead. -->

## What this is

<One or two sentences. What the thing does and who it is for — not how it is built.>

## Build, run, test

    <build command>
    <run command>
    <test command>

<The one command that decides whether the tree is green. Name it explicitly: it is the
command the branch workflow in ~/.claude/CLAUDE.md refers to.>

## Traps

<!-- Only what a competent person gets wrong on the FIRST attempt, and the symptom by
     which they recognise it. A trap without its symptom gets argued with; a trap with
     one does not. Delete this section if there are none yet — an empty list is honest,
     a padded one is not. -->

  * **<the rule>** — <the failure it prevents, and how it shows up>

## Documents of record

Read these at the start of a session; `/resume` does it for you.

  * `STATE.md` — where the work stopped, what is next
  * `DECISIONS.md` — what was decided and why
  * `FOLLOW-UPS.md` — known defects and deferred work

A behaviour change updates them **in the same commit** as the change.

## Session shape

`/resume` at the start, `/handoff` at the end, `/clear` between tasks.
