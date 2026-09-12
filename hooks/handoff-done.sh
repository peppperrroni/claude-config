#!/usr/bin/env bash
# Record that /handoff ran for the repository containing the working directory, so the
# Stop hook stops reminding for the rest of this session.
#
# It exists as a script rather than as a line in SKILL.md telling the model to touch a
# path because the path contains a derived key, and a key computed by hand in prose is a
# key that will one day be computed differently in the two places that have to agree.
#
# Run from the repository whose handoff just finished.

hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_home="$(dirname "$hooks_dir")"
state_dir="$claude_home/.claude-config-state"

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf '%s\n' 'Not a git repository; nothing recorded.'
  exit 0
}
[ -n "$root" ] || exit 0

# Must match session-start.sh and stop.sh exactly. See session-start.sh for why this is
# a hash and not a flattened path.
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

mkdir -p "$state_dir" 2>/dev/null
date > "$state_dir/$key.handoff" 2>/dev/null

printf '%s\n' 'handoff recorded.'
exit 0
