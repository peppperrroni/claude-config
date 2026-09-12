#!/usr/bin/env bash
# Pull the claude-config repository, quietly, with a hard timeout.
#
# Launched detached by session-start.sh and never waited on, because a synchronous pull
# measured 1.1-1.25s against a warm network -- paid at the start of every single session,
# to deliver a change that is almost never there. The timeout still matters: detached is
# not the same as abandoned, and a hung git would otherwise sit there.
#
# Silent in every failure mode by construction. --ff-only is what makes that safe: it
# declines rather than merging, so an unpushed local commit is never resolved behind my
# back.
#
# No `set -e`: a hook that fails must fail silently, not loudly.

repo="${1:-}"
[ -n "$repo" ] || exit 0
# .git is a directory in a normal clone and a file in a worktree; both are fine.
[ -e "$repo/.git" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0

# GIT_TERMINAL_PROMPT=0 turns a credentials prompt into an immediate failure instead of
# a process that waits forever for a terminal nobody is watching.
GIT_TERMINAL_PROMPT=0 git -C "$repo" pull --ff-only -q >/dev/null 2>&1 &
pid=$!

# `timeout` is not on macOS -- it is coreutils, and BSD ships without it. Poll instead:
# 30 x 0.1s. Fractional sleep is not POSIX but works on GNU and BSD alike.
n=0
while [ "$n" -lt 30 ]; do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.1
  n=$((n + 1))
done

if kill -0 "$pid" 2>/dev/null; then
  kill -TERM "$pid" 2>/dev/null || true
fi
wait "$pid" 2>/dev/null || true

exit 0
