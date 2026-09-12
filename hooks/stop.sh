#!/usr/bin/env bash
# Global Stop hook. Reminds, at most once per session, that the tree is dirty and
# /handoff has not run.
#
# Stop fires at the end of every turn, not at the end of the session, so an unthrottled
# reminder would appear after every message on any dirty tree -- which is most of the
# working day, and is how a warning becomes wallpaper. Three stamps under
# ~/.claude/.claude-config-state/ decide:
#
#   <key>.session   written by session-start
#   <key>.handoff   written by hooks/handoff-done, which /handoff runs as its last step
#   <key>.nagged    written here
#
# Reminder iff the tree is dirty AND neither .handoff nor .nagged is newer than
# .session. Missing .session means silence, not noise: it means the SessionStart hook is
# not wired, and half-wiring should fail quiet.
#
# Never blocks, never writes to the repository, never fails loudly.

hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_home="$(dirname "$hooks_dir")"
state_dir="$claude_home/.claude-config-state"

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0

dirty="$(git -C "$root" status --porcelain 2>/dev/null)" || exit 0
[ -n "$dirty" ] || exit 0

# Must match session-start.sh and handoff-done.sh exactly. See session-start.sh for why
# this is a hash and not a flattened path.
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

key="$(repo_key "$root")"
session="$state_dir/$key.session"
handoff="$state_dir/$key.handoff"
nagged="$state_dir/$key.nagged"

[ -f "$session" ] || exit 0
if [ -f "$handoff" ] && [ "$handoff" -nt "$session" ]; then exit 0; fi
if [ -f "$nagged" ]  && [ "$nagged"  -nt "$session" ]; then exit 0; fi

date > "$nagged" 2>/dev/null

printf '%s\n' 'Uncommitted changes in this repository, and /handoff has not run this session. Run /handoff before /clear, or the reasoning goes with the context.'
exit 0
