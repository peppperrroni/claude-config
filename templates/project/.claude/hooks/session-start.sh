#!/usr/bin/env bash
# SessionStart hook: put STATE.md in front of a fresh context, so the first thing the
# model knows about this project is where the last session stopped.
#
# Silent when there is no STATE.md -- a project that keeps no state document should not
# be nagged on every session.
set -euo pipefail

# Resolve from the script's own location, not the working directory: a hook is not
# guaranteed to run from the project root.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
state="$root/STATE.md"

[ -f "$state" ] || exit 0
[ -s "$state" ] || exit 0

# JSON-escape without depending on jq, which is not installed everywhere.
#
# sed for the backslash and the quote, in that order -- escaping the quote first would
# then have its own backslash escaped again. awk only folds the newlines, and only by
# printing a literal, because gsub() re-interprets backslashes in its replacement and
# the number needed differs between awk implementations.
tab="$(printf '\t')"
escaped="$(tr -d '\r' < "$state" \
  | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$tab/\\\\t/g" \
  | awk 'BEGIN { ORS = "" } { print (NR > 1 ? "\\n" : "") $0 }')"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"STATE.md of this project, verbatim:\\n\\n%s"}}\n' "$escaped"
