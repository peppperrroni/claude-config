#!/usr/bin/env bash
# Global SessionStart hook. Installed into ~/.claude/hooks/ and wired once, machine-wide,
# in ~/.claude/settings.json -- so a new project needs no hook wiring of its own.
#
# Two jobs:
#   1. kick off a background pull of the claude-config repository, so the layer keeps
#      itself current without a manual `git pull` before every session;
#   2. put the current project's STATE.md in front of the fresh context, or say that
#      there is none.
#
# Silent outside a git repository: an ad-hoc session in a scratch directory is not a
# project and should not be told about documents it has no use for.
#
# No `set -e`: a hook that fails must fail silently, not loudly.

hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_home="$(dirname "$hooks_dir")"
source_file="$claude_home/.claude-config-source"
state_dir="$claude_home/.claude-config-state"

# A hash, not a flattened path. The readable version -- lowercase and replace every
# non-alphanumeric -- produced a 120-character filename, which on Windows pushed the whole
# path past the 260-character limit and the stamp silently failed to write. Sixteen hex
# characters cannot do that at any depth, and the shells must agree with the PowerShell
# hooks' choice anyway.
#
# sha256sum is GNU, shasum is what macOS ships, cksum is the POSIX floor. Any of them is
# fine: this only has to be stable on one machine, never portable between them.
repo_key() {  # <path>
  lower="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$lower" | sha256sum | cut -c1-16
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$lower" | shasum -a 256 | cut -c1-16
  else
    printf '%s' "$lower" | cksum | tr -d ' ' | cut -c1-16
  fi
}

# --- 1. background pull ------------------------------------------------------

if [ -f "$source_file" ]; then
  repo="$(tr -d '\r' < "$source_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -1)"
  # -f and an explicit `bash`, not -x and a direct call: in copy mode the installer
  # writes pull.sh with whatever mode the copy produced, and a lost execute bit would
  # turn the background pull into silence that looks exactly like success.
  if [ -n "$repo" ] && [ -f "$hooks_dir/pull.sh" ]; then
    # Detached, with stdio closed. Inheriting this hook's stdout would keep it open and
    # Claude Code would wait for a pull it was never supposed to wait for -- which is the
    # whole reason the pull is in the background.
    ( bash "$hooks_dir/pull.sh" "$repo" >/dev/null 2>&1 </dev/null & ) >/dev/null 2>&1
  fi
fi

# --- 2. project state -------------------------------------------------------

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0

# Stamp the session. stop.sh compares against this to remind at most once per session,
# and stays silent entirely when the stamp is missing -- which is what makes wiring only
# half of this block fail quiet instead of nagging every turn.
mkdir -p "$state_dir" 2>/dev/null && \
  date > "$state_dir/$(repo_key "$root").session" 2>/dev/null

state="$root/STATE.md"

# Plain text, not JSON. Per the hooks reference, SessionStart is one of the four events
# where plain-text stdout from an exit-0 hook becomes context Claude can act on, so the
# JSON envelope is unnecessary -- and with it goes the sed/awk escaping this script used
# to carry, which was the most fragile thing in the repository.
# https://code.claude.com/docs/en/hooks
#
# The one hazard is that stdout IS parsed as JSON when it starts with { and ends with }.
# The header line below guarantees it never starts with {, whatever STATE.md holds.
if [ ! -f "$state" ] || [ ! -s "$state" ]; then
  printf '%s\n' 'No state documents in this project; /init-project creates them.'
  exit 0
fi

printf '%s\n\n' 'STATE.md of this project, verbatim:'
tr -d '\r' < "$state"
exit 0
