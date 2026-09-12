---
name: init-project
description: Give the current repository the state documents that /resume and /handoff expect
disable-model-invocation: true
---

Put the project template into this repository, filling in only what cannot be inferred.

Nothing here overwrites. A file that already exists is reported and left exactly as it
was — this skill is run on repositories that are already underway at least as often as on
empty ones, and a template that clobbers a real `CLAUDE.md` is worse than no template.

## 1. Refuse unless this is a repository root

    git rev-parse --show-toplevel

If that fails, this is not a git repository: say so and stop. If it succeeds but does not
equal the working directory, say which directory is the root and stop — state documents
belong at the root, and creating them in a subdirectory silently is how a project ends up
with two.

## 2. Find the templates

Read `~/.claude/.claude-config-source`. It holds the absolute path of the claude-config
clone, written by the installer; the templates are at `<that>/templates/project`.

If the file is missing, setup has not been run on this machine — say so and stop rather
than guessing at a path.

## 3. Copy what is missing

Every entry in `templates/project/`, into the repository root:

    CLAUDE.md  STATE.md  DECISIONS.md  FOLLOW-UPS.md  .gitignore

**`.gitignore` is the exception to plain copying.** If the repository has none, copy it.
If it has one, append the template's line only when it is not already there. Appending to
a `.gitignore` is safe; replacing one is not.

**Dotfiles do not match `*`.** Copy by name, or with a method that includes them — a
glob that quietly skips `.gitignore` will look like it worked.

Then report two lists, both of them, even when one is empty:

    created:  STATE.md, DECISIONS.md, FOLLOW-UPS.md
    skipped:  CLAUDE.md (already exists), .gitignore (already had the line)

## 4. Fill in CLAUDE.md — only if you created it

If `CLAUDE.md` already existed, skip this step entirely and say so. Do not offer to
improve it.

Otherwise ask three questions, and wait for the answers:

1. **What is this?** One or two sentences — what the thing does and who it is for.
2. **How is it built, run and tested?** The actual commands.
3. **Which one command decides whether the tree is green?** The branch workflow in the
   global `CLAUDE.md` refers to exactly this command, so it has to be named.

Fill those into the skeleton. Leave the `Traps` section as the template left it: a trap
is something learned by getting it wrong, and inventing one at initialisation time
produces a plausible sentence that nobody has ever verified.

## 5. Show what happened

    git status

Then stop. **Do not commit.** The first commit of a project's state documents is a
decision about what the project is, and it should be read before it is made.

## Two rules that override the steps above

**Never overwrite.** If a step seems to require replacing an existing file, it is the
step that is wrong. Report and move on.

**Describe no code and no structure.** The answers to step 4 go in as given. Do not read
the repository and elaborate on them — a `CLAUDE.md` that documents what the code
currently looks like is out of date on the next commit, and it was never its job.
