# claude-config

My portable Claude Code layer: the guidance that is true regardless of which project I
am in and which machine I am on. Everything here is installed into `~/.claude` by a
setup script, as symlinks by default, so editing the repository edits the live config.

## What is here

    CLAUDE.md               Global guidance: how to read files, documents of record,
                            test discipline, branch and commit workflow.
                            A project's own CLAUDE.md overrides all of it.

    rules/                  Path-scoped rules. Each .md file declares the globs it
                            applies to, and reaches the model only when a matching
                            file is opened with Read. See rules/README.txt.

    rules/powershell.md     Check for pwsh, fall back to Windows PowerShell.
    rules/ui-automation.md  Synthesise keystrokes with keybd_event/SendInput,
                            not SendKeys.

    skills/handoff/         `/handoff` — record the state of the project at the end of
                            a session. Discovers whichever documents of record the
                            project keeps; creates none. Not model-invocable: it runs
                            when I ask for it and not otherwise.

    setup.sh, setup.ps1     Installers. See below.

## Install

    git clone <this repo> ~/claude-config

    # macOS / Linux
    ~/claude-config/setup.sh

    # Windows
    powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\claude-config\setup.ps1

Both scripts:

  * symlink `CLAUDE.md`, each `rules/*.md` and each `skills/<name>` into `~/.claude`
  * merge one entry at a time, and never replace `~/.claude/rules` or
    `~/.claude/skills` wholesale — unrelated rules and skills already there survive
  * leave `rules/README.txt` behind: it is documentation, and a `.md` file in that
    directory would be loaded as a rule
  * back up whatever is at the destination as `<name>.bak-<timestamp>` before replacing
  * are idempotent: re-running changes nothing once the links are correct
  * take `--copy` (`-Copy` on Windows) to force copies instead of symlinks

Each script probes once whether this account may create symlinks and reports the mode it
actually used. On Windows a symlink needs Administrator or Developer Mode; Git Bash also
needs `MSYS=winsymlinks:nativestrict`, and without it `ln -s` silently produces a copy.
When symlinks are unavailable both scripts copy instead and say so. A copied install does
not track edits to the repository — re-run the script after pulling.

## settings.json is never written

Neither script touches `~/.claude/settings.json` or `settings.local.json`. Those files
hold live state — enabled plugins, MCP servers, permission grants accumulated over
months — and a merge performed by a script is a good way to lose some of it quietly.
The installer prints the keys worth having and leaves the editing to me, for example:

    "tui": "fullscreen",
    "autoUpdatesChannel": "latest"

## Optional: reset reminder

A `SessionStart` hook that fires after `/clear` and `/compact` and reminds the fresh
context that it is fresh. Paste into a **project**'s `.claude/settings.json` — not into
this repository, and not into `~/.claude/settings.json`, which nothing here writes.

The two variants differ only in quoting, and they are not interchangeable: the hook
command is handed to a shell, and `cmd.exe` keeps double quotes that `sh` would strip
while `sh` needs the single quotes that `cmd.exe` would print literally.

### Windows

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo {\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"Context was just cleared. If decisions were made before this point that are not yet recorded in the documents of record, say so now.\"}}"
          }
        ]
      }
    ]
  }
}
```

### macOS / Linux

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo '{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"Context was just cleared. If decisions were made before this point that are not yet recorded in the documents of record, say so now.\"}}'"
          }
        ]
      }
    ]
  }
}
```

### Which one applies

Claude Code picks the shell like this: `$SHELL -c` when `SHELL` is set, otherwise
`%COMSPEC% /d /s /c` on Windows, otherwise `/bin/sh -c`. So the Windows block is right
when Claude Code is started from PowerShell, `cmd`, or a shortcut — `SHELL` is unset
there. Start it from Git Bash and `SHELL` is set, and the macOS/Linux block applies
instead, on Windows.

Verified here: `cmd.exe /d /s /c` reproduces the Windows block's JSON byte for byte, and
`sh -c` reproduces the other. What could not be verified without a live hook is how the
command string reaches `cmd.exe` — if the quotes arrive escaped, the hook emits
`{\"hookSpecificOutput\"...}` and Claude Code ignores it as malformed. Check it in one
step: add the block, run `/clear`, and see whether the reminder arrives. If nothing
appears, the quoting is the reason.

## What is deliberately excluded, and why

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
