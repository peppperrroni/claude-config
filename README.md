# claude-config

My portable Claude Code layer: the guidance that is true regardless of which project I am
in and which machine I am on.

A new machine is three steps: **clone, run setup, paste one block.** After that the layer
keeps itself current and nothing here needs running again by hand.

## 1. What this is

Two trees, one of which is generated from the other.

    ~/claude-config/          the source of truth. Version controlled. Edited here.
    ~/.claude/                the live configuration. Read by Claude Code. Generated.

`setup.ps1` / `setup.sh` install the first into the second — as symlinks when the
platform allows, so that editing the repository edits the live config, and as copies when
it does not.

    ~/claude-config/                    ~/.claude/
      CLAUDE.md              ───────►     CLAUDE.md
      rules/*.md             ───────►     rules/*.md
      rules/README.txt       ───╳         (not installed: documentation, not a rule)
      skills/handoff/        ───────►     skills/handoff/
      skills/resume/         ───────►     skills/resume/
      skills/init-project/   ───────►     skills/init-project/
      hooks/*                ───────►     hooks/*
      templates/             ───╳         (not installed: /init-project copies these)
      .githooks/             ───╳         (not installed: runs inside this repo)
                             ───╳         settings.json        (never written)
                             ───╳         settings.local.json  (never written)
                                          skills/<anything else> survives untouched
                                          .claude-config-manifest  written by setup
                                          .claude-config-source    written by setup
                                          .claude-config-state/    written by the hooks

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

    skills/resume/                  /resume — read the project's state back at the start
                                    of a session.
    skills/handoff/                 /handoff — write it at the end.
    skills/init-project/            /init-project — give a repository the state documents
                                    the other two expect.
                                    All three are disable-model-invocation: they run when
                                    I ask and not otherwise.

    hooks/session-start.{ps1,sh}    SessionStart: background-pull this repository, then
                                    show the project's STATE.md.
    hooks/stop.{ps1,sh}             Stop: remind once per session that the tree is dirty
                                    and /handoff has not run.
    hooks/pull.{ps1,sh}             The timed, silent pull. Launched detached.
    hooks/handoff-done.{ps1,sh}     Marks that /handoff ran, which silences the reminder.

    templates/project/              Skeleton for a new project. Copied by /init-project.
    templates/project/CLAUDE.md     Project guidance skeleton.
    templates/project/STATE.md      Where work stopped, what is next.
    templates/project/DECISIONS.md  What was decided and why.
    templates/project/FOLLOW-UPS.md Known defects and deferred work.
    templates/project/.gitignore    Ignores .claude/settings.local.json.

    .githooks/post-merge            Re-runs setup after a pull. Wired by setup with
    .githooks/post-merge.ps1        core.hooksPath, in this repository only.

    setup.ps1, setup.sh             Installers. See below.
    .gitattributes                  Line endings: .sh is LF, .ps1 is CRLF, .md is LF.
    .gitignore                      Backups, and settings.local.json anywhere.

## 3. Install

    git clone https://github.com/peppperrroni/claude-config.git ~/claude-config

**Windows — use `setup.ps1`, never `setup.sh`.** See §11 for why.

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
| `copy` | the probe failed, or `-Copy` / `--copy` was passed | the live config is a snapshot, refreshed by the post-merge hook (§5) |

On Windows a symlink needs Administrator or Developer Mode (Settings → System → For
developers → Developer Mode). Git Bash additionally needs
`MSYS=winsymlinks:nativestrict`; without it `ln -s` returns success and silently produces
a copy, which is why `setup.sh` checks `[ -L ]` as well as the exit status.

*Verified on Windows 11 with Developer Mode off and an unelevated shell: the probe fails
and the installer reports `mode: copy`. Link mode has not been exercised end to end on
Windows for the same reason.*

**A note on the "verified" notes.** They say what was tested and on what kind of machine,
never on which machine: no home directory paths, usernames, kernel builds or hostnames.
That is §10's rule — what I decided, never where I ran it — applied to this file, which is
otherwise the easiest place in the repository to leak it.

### Options

| `setup.ps1` | `setup.sh` | Effect |
|---|---|---|
| `-Copy` | `--copy` | force copies even where symlinks would work |
| `-Prune` | `--prune` | delete entries a previous run installed that are gone from the source |
| — | `-h`, `--help` | usage |

### CLAUDE_HOME

Both scripts install into `$CLAUDE_HOME` when it is set, and into `~/.claude` otherwise.
That is the supported way to try a change without touching the live configuration, and
the hooks honour it too — each resolves `~/.claude` from its own location rather than
from `$HOME`, so a sandboxed install's hooks read that sandbox's state:

    $env:CLAUDE_HOME = "$env:TEMP\claude-sandbox"      # PowerShell
    CLAUDE_HOME=/tmp/claude-sandbox ./setup.sh          # sh

### Reading the output

    Installed into C:\Users\<user>\.claude (mode: copy)

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
the manifest and is therefore not a candidate — on a machine with skills linked in from
elsewhere, they survive. `settings.json`, `settings.local.json`, `.credentials.json` and
the installer's own two dotfiles are refused outright even if a hand-edited manifest
names them, and a path that resolves outside the destination is skipped.

The manifest grows and shrinks, and it is worth being exact about when, because "union of
everything ever installed" and "prune works" cannot both be true.

**An install adds.** The manifest is rewritten as the union of what it already held and
what was just installed. Rewriting it with only the current set is the obvious
implementation and is wrong: it would erase the record of exactly the entries prune exists
to find, one run before prune could act on them.

**Two things remove.** A pruned entry is dropped in the same run that deletes it. So is an
entry whose destination is already gone — pruned earlier, or deleted by hand — since there
is nothing left to clean and no reason to keep reporting it.

**Nothing else does.** Without `-Prune` / `--prune` a stale entry is reported and *kept*,
so the next run reports it again. That is the point: the flag is a decision, and until it
is made the report should not go quiet.

*Verified in a `CLAUDE_HOME` sandbox, four consecutive runs: install; delete a rule from
the source and run again — reported stale, nothing changed; run with `-Prune` — that one
file deleted and nothing else; **run a fourth time — silent, and the entry is gone from
the manifest.** Separately, deleting a whole skill directory and pruning removed it while
an unrelated pre-existing skill, `settings.json` and `settings.local.json` were
untouched.*

## 4. Machine setup — the one paste

Setup never writes `settings.json`. It ends by **printing** a block, with this machine's
absolute paths already filled in:

    {
      "hooks": {
        "SessionStart": [
          { "hooks": [ { "type": "command", "command": "<...>/hooks/session-start.ps1" } ] }
        ],
        "Stop": [
          { "hooks": [ { "type": "command", "command": "<...>/hooks/stop.ps1" } ] }
        ]
      }
    }

Paste it into `~/.claude/settings.json`, merging the `hooks` key if the file already has
one. That is the only manual configuration on a new machine, and it is the last one.

**Why printed and not written.** `settings.json` holds live state — enabled plugins, MCP
servers, permission grants accumulated over months — and the file is rewritten by the CLI
itself. A merge performed by a script is a good way to lose some of it quietly, and to
collide with a program that does not know about git.

### What the two hooks do

**SessionStart** starts a detached, timed pull of this repository, then puts the current
project's `STATE.md` in front of the fresh context. With no `STATE.md` it says
`No state documents in this project; /init-project creates them.` Outside a git
repository it says nothing at all — an ad-hoc session in a scratch directory is not a
project.

**Stop** fires at the end of every turn. If the tree is dirty it reminds, **once per
session**, that `/handoff` has not run. It never blocks and never writes to the
repository.

Three stamps under `~/.claude/.claude-config-state/` make the throttle work: `.session`
written by SessionStart, `.handoff` written by `/handoff` as its last step, `.nagged`
written by Stop itself. The reminder appears only when neither `.handoff` nor `.nagged`
is newer than `.session`.

**Wire both or neither.** With no `.session` stamp the Stop hook exits silently rather
than guessing — so wiring only the Stop half produces nothing at all, instead of a
reminder after every single message.

### Why the pull is in the background

Measured on this machine, warm network: `git pull --ff-only` against this repository took
**1.09–1.25 s**. That is paid at the start of every session, to deliver a change that is
usually not there. So SessionStart launches `hooks/pull.*` detached and does not wait; the
3-second hard timeout lives inside that child, because detached is not the same as
abandoned.

The pulled content therefore lands for the *next* session in copy mode, and immediately in
link mode. That is the trade for not paying a second per session.

`--ff-only` is what makes a silent background pull safe: it declines rather than merging,
so an unpushed local commit is never resolved behind my back. Offline, mid-conflict, no
git, no repository, a credentials prompt — every one of those is a silent no-op.

*Verified on Windows: the hook emits correct JSON with `STATE.md` present, the one-line
hint with it absent, and nothing outside a git repository; the whole hook takes ~350 ms,
of which ~285 ms is PowerShell's own startup, and it stays that fast with the source path
pointing at a directory that does not exist. The Stop hook was exercised through all seven
states — clean, dirty, repeat-in-session, new session, after `handoff-done`, and after
that. The shell versions produce byte-identical decisions under WSL bash 5.2.*

***Unverified on every platform:*** *whether Claude Code consumes the SessionStart JSON
and the Stop output at all. That is what §11's one-step test is for, and until it is run
this whole section describes scripts that are known to work and a wiring that is not.*

## 5. Updating after a pull

    cd ~/claude-config && git pull

**Nothing else.** Setup sets `git config core.hooksPath .githooks` in this repository, and
`.githooks/post-merge` re-runs the installer with `--prune` after every merge. In copy
mode that refreshes the copies; in link mode everything is already current and the run
reports `unchanged`, except for files the pull *added*, which have no link yet.

`--prune` is why the deletion case works too: a pull that removed a rule takes its
installed copy, or its now-dangling symlink, with it.

*Verified end to end on Windows, through a real remote: a second clone added a rule and
pushed it; `git pull` in the first clone ran the installer and the rule appeared in the
destination. The same clone then deleted the rule and pushed; the next `git pull` reported
`pruned` and it was gone.*

The trade: `core.hooksPath` bypasses `.git/hooks` in this repository, and every pull now
prints the installer's full output. Both are visible and neither is reversible by
accident — `git config --unset core.hooksPath` undoes it.

If setup reports that it could **not** set `core.hooksPath` — the source is not a git
repository, or git is unavailable — then the old rule applies and the installer has to be
re-run by hand after every pull.

## 6. Adding a rule

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

Commit and push it; the next machine picks it up on its next pull.

## 7. Adding a skill

A skill is a directory under `skills/` containing `SKILL.md`:

    ---
    name: <name>
    description: <one line; this is what the model matches against>
    disable-model-invocation: true
    ---

    <the steps>

`disable-model-invocation: true` means the skill runs when I type `/<name>` and never
because the model decided it was relevant. All three skills here set it: they read and
write the documents of record, and none of that should happen as a side effect of
something else.

The installer adds skill directories one at a time, so whatever else is already in
`~/.claude/skills` survives.

## 8. Starting a new project

In the repository, at its root:

    /init-project

It copies `templates/project/` into the repository — `CLAUDE.md`, `STATE.md`,
`DECISIONS.md`, `FOLLOW-UPS.md`, `.gitignore` — **overwriting nothing**, reports what it
created and what it skipped, and if it created `CLAUDE.md` asks the three questions needed
to fill it in: what this is, the build/run/test commands, and the one command that decides
whether the tree is green. Where a `.gitignore` already exists it appends the one line
instead of replacing the file. It shows `git status` and does not commit.

It finds the templates by reading `~/.claude/.claude-config-source`, which setup wrote
with the path of the clone.

**No hook wiring.** There used to be a per-project `.claude/` with its own SessionStart
hook and a `settings.json.example` carrying two invocation variants. That is gone: the
hooks are global now (§4), they find the project from the working directory, and a new
project inherits them by existing. One wiring decision per machine instead of one per
repository.

## 9. Session workflow

    /resume   →   work   →   /handoff   →   /clear

`/resume` reads `CLAUDE.md`, the state documents, `git status` and `git log -10`, says
where the last session stopped and what is open, proposes one next step, and changes
nothing. `/handoff` does the reverse at the end: it updates the documents to match what
the session actually did, shows the diff, does not commit, and marks itself done so the
Stop reminder goes quiet.

The hooks cover the edges. SessionStart has already put `STATE.md` in front of the context
before `/resume` is typed — `/resume` is the deliberate, fuller read, the hook is the
free one. Stop catches the session that is about to end with a dirty tree and no handoff.

Both skills refuse to invent. `/resume` stops and says so when a project keeps no state
documents; `/handoff` will not create documents the project never asked for; `/init-project`
is how a project gets them, deliberately and once.

**Why the state documents live in the project repository** and not in
`~/.claude/projects/`: they are part of the project's history, not of my machine's. They
belong in the same commit as the behaviour they describe, they should reach anyone who
clones the repository, and they should survive this laptop. `~/.claude/projects/` is
keyed by absolute path, is never backed up, and is excluded from this repository for the
same reason as everything else in §10.

## 10. What is deliberately excluded, and why

| Not in this repo | Why |
|---|---|
| `~/.claude/settings.json` | Enabled plugins and marketplaces are per-machine facts, and the file is rewritten by the CLI itself. Publishing it invites a merge conflict with a program that does not know about git. The hook block is printed by setup instead, with this machine's paths. |
| `~/.claude/settings.local.json` | Permission grants. Mine include absolute paths under my home directory, and a grant copied onto another machine authorises something nobody reviewed there. Permissions should be granted where they are used. |
| `~/.claude/.credentials.json` | Authentication tokens. Never belongs in a repository, private or otherwise. |
| `~/.claude/.claude-config-source`, `.claude-config-state/` | Where this clone happens to live, and which repositories were touched when. Machine facts, written by setup and the hooks, prune refuses to touch them. |
| `~/.claude/projects/` | Per-project memory and transcripts, keyed by absolute path. Full of product decisions that mean nothing outside their repository. |
| `~/.claude/sessions/`, `history.jsonl`, `shell-snapshots/`, `file-history/` | Verbatim session history: source code, file contents, anything pasted into a prompt. The single largest disclosure risk in `~/.claude`. |
| `~/.claude/skills/` as a directory | Symlinks into another tree, resolved against absolute paths that exist on one machine. The installer adds skills individually for this reason. |

The rule behind the table: this repository holds what I decided, never what I ran, where
I ran it, or what let me in.

## 11. Troubleshooting

### `bash` on Windows is WSL, and `setup.sh` will lie to you

    PS> Get-Command bash

    Name        : bash.exe
    CommandType : Application
    Source      : C:\Windows\system32\bash.exe

That is not Git Bash. `C:\Windows\system32\bash.exe` is the WSL launcher, and inside it
`$HOME` is a Linux home under `/home/`, on a WSL2 kernel — a different filesystem
entirely.

So `bash setup.sh` installs into `~/.claude` **inside the WSL distribution**, reports
success, and changes nothing that the Windows Claude Code reads. **On Windows use
`setup.ps1` only.**

Check before trusting a shell: `Get-Command bash` for the path, and `bash -c 'echo $HOME;
uname -sr'` — a Linux answer means WSL.

### The hooks do nothing

**Status: unverified on Windows and on macOS.** The hook scripts are verified to behave
correctly when run directly (§4); what has not been tested on either platform is whether
Claude Code invokes them and acts on their output.

**The one-step test.** Wire the block from §4, open a session in a project that has a
`STATE.md`, and see whether it comes back. Nothing appearing is the failure — a malformed
or misrouted hook is ignored silently rather than reported.

If nothing appears, in order:

1. **Run the script by hand,** from inside the project:

       powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.claude\hooks\session-start.ps1

   It should print one line of JSON. If it does, the script is fine and the wiring is not.

2. **Wrong shell for the command string.** *Unverified, and a claim about Claude Code
   rather than about anything here:* a hook command is said to run through `$SHELL -c`
   when `SHELL` is set, `%COMSPEC% /d /s /c` on Windows otherwise, and `/bin/sh -c`
   otherwise. If that holds, a session started from Git Bash or WSL on Windows wants the
   `bash .../session-start.sh` form rather than the `powershell ... .ps1` one. Both scripts
   are installed on both platforms precisely so the other one can be tried; swapping the
   command costs one restart and settles it.

3. **Wrong file.** The block belongs in `~/.claude/settings.json`. Nothing here writes it,
   so a typo there is invisible until the hook fails to fire.

4. **Silence is also correct.** Outside a git repository the SessionStart hook prints
   nothing, by design. Test inside a repository.

### The Stop reminder never appears

Check in this order: is the tree actually dirty (`git status --porcelain`); was the
SessionStart hook wired too, and did it write `~/.claude/.claude-config-state/<key>.session`;
has it already reminded this session (`<key>.nagged` newer than `<key>.session`); did
`/handoff` already run (`<key>.handoff` newer than `<key>.session`).

A missing `.session` stamp means silence by design — see §4.

### The config is not updating itself

`git -C ~/claude-config config --get core.hooksPath` should print `.githooks`. If it
prints nothing, setup could not set it, and §5's automatic re-install is not happening —
re-run setup by hand after each pull until it can.

For the background pull, check `~/.claude/.claude-config-source` holds the path of the
clone. A stale path there is silent by design: the pull is a convenience, not a
correctness requirement, and a hook that complained about it would be worse than one that
did not.

### `$'\r': command not found`

`setup.sh` or a hook was checked out with CRLF line endings; bash reads the carriage
return as part of the shebang. `.gitattributes` pins `*.sh` to LF to prevent it. If it
happens anyway, the clone predates that file: `git rm --cached -r . && git reset --hard`
renormalises.

### `pwsh` is not recognised

PowerShell 7 is a separate install and is absent on this machine — `Get-Command pwsh`
finds nothing. Use `powershell` (Windows PowerShell 5.1), which is always present; the
flags are identical. This is what `rules/powershell.md` exists to say.

### macOS is unverified

Every `.sh` here is syntax-checked (`bash -n`, GNU bash 5.2, clean) and the hooks were
exercised under WSL bash, which is Linux and **not** macOS: `/bin/bash` there is 3.2, and
`sed`, `diff` and `tr` are BSD. The constructs that matter were chosen with that in mind —
`${ARR[@]+"${ARR[@]}"}` for empty arrays under `set -u`, `sed` rather than `awk` `gsub`
for JSON escaping, a poll loop rather than `timeout`, which is coreutils and absent on
BSD, and `shasum` as the fallback for `sha256sum` — but chosen with it in mind is not the
same as tested.

Treat the first macOS run as the test, against a scratch destination:

    export CLAUDE_HOME=/tmp/claude-sandbox

    ./setup.sh                      # 1. installs
    ./setup.sh                      # 2. must be all `unchanged`, no backups

    rm rules/ui-automation.md       # (in a throwaway copy of the repo)
    ./setup.sh                      # 3. reports it stale, changes nothing
    ./setup.sh --prune              # 4. deletes exactly that file
    ./setup.sh                      # 5. SILENT — the entry left the manifest

Run 5 is the one that matters and the one that is easiest to skip. If it reports the
entry as stale again, prune removed the file but not the record, and every later run will
keep reporting something that no longer exists.

Then, from inside a project with a `STATE.md`:

    bash $CLAUDE_HOME/hooks/session-start.sh     # one line of JSON
    bash $CLAUDE_HOME/hooks/stop.sh              # silent on a clean tree

Finally check that `$CLAUDE_HOME/settings.json` was never created, and delete the scratch
directory.
