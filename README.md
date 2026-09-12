# claude-config

My portable Claude Code layer: the guidance that is true regardless of which project I am
in and which machine I am on.

## 1. What this is

Two trees, one of which is generated from the other.

    ~/claude-config/          the source of truth. Version controlled. Edited here.
    ~/.claude/                the live configuration. Read by Claude Code. Generated.

`setup.ps1` / `setup.sh` install the first into the second — as symlinks when the
platform allows, so that editing the repository edits the live config, and as copies when
it does not.

    ~/claude-config/                    ~/.claude/
      CLAUDE.md              ───────►     CLAUDE.md
      rules/powershell.md    ───────►     rules/powershell.md
      rules/ui-automation.md ───────►     rules/ui-automation.md
      rules/README.txt       ───╳         (not installed: documentation, not a rule)
      skills/handoff/        ───────►     skills/handoff/
      skills/resume/         ───────►     skills/resume/
      templates/             ───╳         (not installed: copied into a project by hand)
                             ───╳         settings.json        (never written)
                             ───╳         settings.local.json  (never written)
                                          skills/<anything else> survives untouched
                                          .claude-config-manifest  (written by setup)

## 2. Repository layout

    CLAUDE.md                       Global guidance: reading files, documents of record,
                                    context hygiene, tests, branches and commits.
                                    A project's own CLAUDE.md overrides all of it.

    rules/                          Path-scoped rules. Each .md declares the globs it
                                    applies to and reaches the model only when a matching
                                    file is opened with Read.
    rules/README.txt                How the mechanism works. .txt so it is not a rule.
    rules/powershell.md             Check for pwsh, fall back to Windows PowerShell.
    rules/ui-automation.md          Synthesise keystrokes with keybd_event/SendInput,
                                    never SendKeys.

    skills/handoff/                 /handoff — record the state of the project at the end
                                    of a session.
    skills/resume/                  /resume — read that state back at the start of one.
                                    Both are disable-model-invocation: they run when I
                                    ask and not otherwise.

    templates/project/              Skeleton for a new project. Not installed.
    templates/project/CLAUDE.md     Project guidance skeleton.
    templates/project/STATE.md      Where work stopped, what is next.
    templates/project/DECISIONS.md  What was decided and why.
    templates/project/FOLLOW-UPS.md Known defects and deferred work.
    templates/project/.claude/      SessionStart hook that prints STATE.md, in both a
                                    PowerShell and a bash variant, plus a
                                    settings.json.example showing how to wire it.

    setup.ps1, setup.sh             Installers. See below.
    .gitattributes                  Line endings: .sh is LF, .ps1 is CRLF, .md is LF.
    .gitignore                      Backups, and settings.local.json anywhere.

## 3. Install

    git clone https://github.com/peppperrroni/claude-config.git ~/claude-config

**Windows — use `setup.ps1`, never `setup.sh`.** See §10 for why.

    powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\claude-config\setup.ps1

**macOS / Linux**

    ~/claude-config/setup.sh

### Link mode and copy mode

Both scripts probe **once**, before installing anything, whether this account may create
a symlink — by making one and looking at the result. Reporting a mix of linked and copied
paths would leave the install in a state nobody can reason about, so it is one mode for
the whole run.

| Mode | When | Consequence |
|---|---|---|
| `link` | the probe succeeded | editing the repository edits the live config immediately |
| `copy` | the probe failed, or `-Copy` / `--copy` was passed | the live config is a snapshot; **re-run setup after every pull or edit** |

On Windows a symlink needs Administrator or Developer Mode (Settings → System → For
developers → Developer Mode). Git Bash additionally needs
`MSYS=winsymlinks:nativestrict`; without it `ln -s` returns success and silently produces
a copy, which is why `setup.sh` checks `[ -L ]` as well as the exit status.

*Verified on this machine (Windows 11, 2026-09-12): Developer Mode off, shell not
elevated, so the probe fails and the installer reports `mode: copy`.*

### Options

| `setup.ps1` | `setup.sh` | Effect |
|---|---|---|
| `-Copy` | `--copy` | force copies even where symlinks would work |
| `-Prune` | `--prune` | delete entries a previous run installed that are gone from the source |
| — | `-h`, `--help` | usage |

### CLAUDE_HOME

Both scripts install into `$CLAUDE_HOME` when it is set, and into `~/.claude` otherwise.
That is the supported way to try a change without touching the live configuration:

    $env:CLAUDE_HOME = "$env:TEMP\claude-sandbox"      # PowerShell
    CLAUDE_HOME=/tmp/claude-sandbox ./setup.sh          # sh

### Reading the output

    Installed into C:\Users\viohn\.claude (mode: copy)

      unchanged   ...\CLAUDE.md  (copy)      already correct; nothing done
      link        ...\rules\x.md  ->  ...    a new symlink was created
      copy        ...\rules\x.md             a new copy was written
      backed up   ...\x.md.bak-20260912-...  what was there first was moved aside
      stale       ...\rules\old.md           installed once, gone from the source now
      pruned      ...\rules\old.md           the same, deleted because -Prune was passed

A clean re-run is all `unchanged` and nothing else. Anything replaced is first moved to
`<name>.bak-<timestamp>`; those accumulate, and deleting them is a manual job. `*.bak-*`
is in `.gitignore` so one made inside the repository is never committed.

### How prune knows what is its own

The installer writes `~/.claude/.claude-config-manifest`: one installed path per line,
relative to the destination, which is also its path relative to the source because the
two trees mirror each other.

Prune considers **only** paths in that manifest, and only those that no longer exist in
the source. A skill in `~/.claude/skills` that this repository did not install is not in
the manifest and is therefore not a candidate — on this machine there are twelve
junctions there pointing into `~/.agents/skills`, and they survive. `settings.json`,
`settings.local.json` and `.credentials.json` are refused outright even if a hand-edited
manifest names them, and a path that resolves outside the destination is skipped.

The manifest is the **union** of what was installed before and what was installed just
now. Rewriting it with only the current set would erase the record of exactly the entries
prune exists to find.

Without `-Prune` / `--prune`, stale entries are reported and left alone.

*Verified in a `CLAUDE_HOME` sandbox: removing `rules/ui-automation.md` from the source
made the next run report it as stale and change nothing; the run after that with `-Prune`
deleted that one file and nothing else; removing `skills/handoff` and pruning deleted
that directory while a pre-existing unrelated skill, `settings.json` and
`settings.local.json` were untouched.*

### settings.json is never written

Neither script touches `~/.claude/settings.json` or `settings.local.json`. Those files
hold live state — enabled plugins, MCP servers, permission grants accumulated over months
— and a merge performed by a script is a good way to lose some of it quietly. The
installer prints the keys worth having and leaves the editing to me:

    "tui": "fullscreen",
    "autoUpdatesChannel": "latest"

## 4. Updating after a pull

    cd ~/claude-config && git pull

**Link mode:** nothing more to do. The links already point at the new content. Re-run the
installer only when a rule or skill was *added*, since a new file has no link yet.

**Copy mode:** the pull changed nothing that Claude Code can see. Re-run the installer:

    powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\claude-config\setup.ps1

Add `-Prune` / `--prune` when the pull deleted a rule or a skill; without it the old copy
stays in `~/.claude` and keeps being loaded. The run tells you which entries are stale, so
the safe habit is to run once without the flag, read the report, and run again with it.

## 5. Adding a rule

A rule is an `.md` file in `rules/` whose frontmatter names the globs it applies to:

    ---
    paths:
      - "**/*.ps1"
      - "**/scripts/**"
    ---

    # What a competent person gets wrong here

    <the rule>

    <the failure it prevents, and the symptom by which it is recognised>

Three things to keep in mind:

  * **A rule with no `paths:` is not scoped and is paid for in every session.** If
    something is true everywhere it belongs in `CLAUDE.md`, where it is at least visible
    in one place.
  * **Scope anything platform-specific** so it costs nothing elsewhere. A Swift or Xcode
    rule takes `"**/*.swift"`, `"**/*.xcodeproj/**"` and stays inert on Windows. (None
    exists yet; adding one before there is a project to need it would be paying for
    nothing.)
  * **State the breakage, not just the conclusion.** A rule that only says what to do
    gets argued with; one that says what goes wrong when you do the other thing does not.
    `rules/ui-automation.md` is the shape: use `SendInput`, because `SendKeys` is
    invisible to the low-level input path, and the symptom is a key binding that
    registers without error and then does nothing.

`rules/README.txt` is `.txt` on purpose: every `.md` in that directory is loaded as a
rule, and notes addressed to a human reader are not rules.

Then re-run the installer — a new file has no link or copy yet.

## 6. Adding a skill

A skill is a directory under `skills/` containing `SKILL.md`:

    ---
    name: <name>
    description: <one line; this is what the model matches against>
    disable-model-invocation: true
    ---

    <the steps>

`disable-model-invocation: true` means the skill runs when I type `/<name>` and never
because the model decided it was relevant. Both skills here set it: `/handoff` and
`/resume` write and read the documents of record, and neither should happen as a side
effect of something else.

The installer adds skill directories one at a time, so whatever else is already in
`~/.claude/skills` survives.

## 7. Starting a new project from the template

Templates are not installed. Copy them:

    # Windows
    Copy-Item -Recurse $HOME\claude-config\templates\project\* <new-project>\ -Force

    # macOS / Linux
    cp -R ~/claude-config/templates/project/. <new-project>/

Then:

1. Fill in `CLAUDE.md` — what it is, the build/run/test commands, the traps. Name the one
   command that decides whether the tree is green; the branch workflow refers to it.
2. Leave `STATE.md`, `DECISIONS.md` and `FOLLOW-UPS.md` as skeletons. `/handoff` fills
   them in. Each says at the top what belongs in it and what does not — that header is
   the point of the file and should survive.
3. Wire the SessionStart hook, which prints `STATE.md` into a fresh context. Open
   `.claude/settings.json.example`, take the `_windows` or the `_posix` object (see §10),
   and put its contents into `.claude/settings.local.json` — local, because the
   invocation is a fact about the machine and not about the project.
4. Add `.claude/settings.local.json` to the project's `.gitignore`.

Both hook scripts locate the project from their own path rather than the working
directory, exit silently when there is no `STATE.md`, and emit JSON built by a real
serialiser rather than by hand.

*Verified: both scripts produce valid, correctly escaped JSON for content containing
quotes, backslashes, tabs, CRLF and non-ASCII — `session-start.ps1` under Windows
PowerShell 5.1, `session-start.sh` under bash 5.2.21. **Unverified on every platform:**
whether Claude Code then acts on that JSON. See §10 for the one-step test.*

## 8. Session workflow

    /resume   →   work   →   /handoff   →   /clear

`/resume` reads `CLAUDE.md`, the state documents, `git status` and `git log -10`, says
where the last session stopped and what is open, proposes one next step, and changes
nothing. `/handoff` does the reverse at the end: it updates the documents to match what
the session actually did, shows the diff, and does not commit.

Both refuse to invent. `/resume` stops and says so when a project keeps no state
documents; `/handoff` will not create documents the project never asked for.

**Why the state documents live in the project repository** and not in
`~/.claude/projects/`: they are part of the project's history, not of my machine's. They
belong in the same commit as the behaviour they describe, they should reach anyone who
clones the repository, and they should survive this laptop. `~/.claude/projects/` is
keyed by absolute path, is never backed up, and is excluded from this repository for the
same reason as everything else in §9.

## 9. What is deliberately excluded, and why

| Not in this repo | Why |
|---|---|
| `~/.claude/settings.json` | Enabled plugins and marketplaces are per-machine facts, and the file is rewritten by the CLI itself. Publishing it invites a merge conflict with a program that does not know about git. |
| `~/.claude/settings.local.json` | Permission grants. Mine include absolute paths under my home directory, and a grant copied onto another machine authorises something nobody reviewed there. Permissions should be granted where they are used. |
| `~/.claude/.credentials.json` | Authentication tokens. Never belongs in a repository, private or otherwise. |
| `~/.claude/projects/` | Per-project memory and transcripts, keyed by absolute path. Full of product decisions that mean nothing outside their repository. |
| `~/.claude/sessions/`, `history.jsonl`, `shell-snapshots/`, `file-history/` | Verbatim session history: source code, file contents, anything pasted into a prompt. The single largest disclosure risk in `~/.claude`. |
| `~/.claude/skills/` as a directory | Symlinks into `~/.agents/skills`, resolved against absolute paths that exist on one machine. The installer adds skills individually for this reason. |

The rule behind the table: this repository holds what I decided, never what I ran, where
I ran it, or what let me in.

## 10. Troubleshooting

### `bash` on Windows is WSL, and `setup.sh` will lie to you

    PS> Get-Command bash

    Name        : bash.exe
    Source      : C:\Windows\system32\bash.exe
    Version     : 10.0.26100.9278

That is not Git Bash. It is the WSL launcher, and inside it:

    HOME=/home/viohneq
    Linux 6.6.87.2-microsoft-standard-WSL2

So `bash setup.sh` on this machine installs into `/home/viohneq/.claude` **inside the
Ubuntu WSL distribution**, reports success, and changes nothing that the Windows Claude
Code reads. **On Windows use `setup.ps1` only.**

### Symlinks were refused

The installer says so and copies instead. Enable Developer Mode (Settings → System → For
developers) or run elevated, then re-run `setup.ps1` once; it will replace the copies with
links. Until then the live config is a snapshot — re-run the installer after every pull
or edit.

### `$'\r': command not found`

`setup.sh` was checked out with CRLF line endings; bash reads the carriage return as part
of the shebang. `.gitattributes` pins `*.sh` to LF to prevent it. If it happens anyway,
the clone predates that file: `git rm --cached -r . && git reset --hard` renormalises.

### `pwsh` is not recognised

PowerShell 7 is a separate install and is absent here — `Get-Command pwsh` finds nothing
on this machine. Use `powershell` (Windows PowerShell 5.1), which is always present; the
flags are identical. This is what `rules/powershell.md` exists to say.

### The SessionStart hook does nothing

**Status: unverified on Windows and on macOS.** The hook scripts are verified to produce
valid JSON (§7); what has not been tested on either platform is whether Claude Code picks
that JSON up.

The one-step test: wire the hook per §7, run `/clear`, and see whether `STATE.md` comes
back. Nothing appearing is the failure — a malformed or misrouted hook is ignored
silently rather than reported.

If nothing appears, in order:

1. **Wrong variant.** Claude Code runs a hook through `$SHELL -c` when `SHELL` is set,
   otherwise `%COMSPEC% /d /s /c` on Windows, otherwise `/bin/sh -c`. Started from
   PowerShell, `cmd` or a shortcut, `SHELL` is unset and `_windows` applies; started from
   Git Bash or WSL, `SHELL` is set and `_posix` applies — on Windows too.
2. **Relative path.** The command in the example is relative to the project directory.
   Try an absolute one.
3. **Wrong file.** It belongs in `.claude/settings.local.json` in the *project*, not in
   `~/.claude/settings.json`, which nothing here writes.
4. **The script itself.** Run it by hand; it should print one line of JSON. Silence means
   it found no `STATE.md`.

### macOS is unverified

`setup.sh` has been syntax-checked (`bash -n`, GNU bash 5.2.21, clean) but **never run to
completion on macOS**, whose `/bin/bash` is 3.2 and whose `sed` and `diff` are BSD. The
constructs that matter were chosen with that in mind — `${ARR[@]+"${ARR[@]}"}` for empty
arrays under `set -u`, `sed` rather than `awk` `gsub` for JSON escaping — but chosen with
it in mind is not the same as tested. Treat the first macOS run as a test, with
`CLAUDE_HOME` pointed at a scratch directory.
