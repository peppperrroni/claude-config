#!/usr/bin/env bash
# Install this repository's Claude Code layer into ~/.claude.
# Symlinks by default, so editing the repository edits the live config.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WANT="link"
REPORT=()

usage() {
  cat <<'USAGE'
usage: setup.sh [--copy]

  --copy    install copies instead of symlinks. Copies do not track edits to
            this repository -- re-run setup.sh after pulling.

Installs into $CLAUDE_HOME if set, otherwise ~/.claude.
Never writes settings.json; prints what to add by hand instead.
Safe to re-run: anything already current is left alone.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --copy)    WANT="copy" ;;
    -h|--help) usage; exit 0 ;;
    *)         printf 'setup.sh: unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

note() { REPORT+=("$1"); }

mkdir -p "$DEST" "$DEST/rules" "$DEST/skills"

# Some filesystems accept `ln -s` and silently produce a copy -- Git Bash on
# Windows does exactly that unless MSYS=winsymlinks:nativestrict is set. Find out
# once, here, rather than reporting a link that is not one.
MODE="$WANT"
if [ "$WANT" = "link" ]; then
  probe="$DEST/.setup-symlink-probe.$$"
  rm -rf "$probe"
  if ln -s "$SRC/CLAUDE.md" "$probe" 2>/dev/null && [ -L "$probe" ]; then
    MODE="link"
  else
    MODE="copy"
    SYMLINKS_UNAVAILABLE=1
  fi
  rm -rf "$probe"
fi
: "${SYMLINKS_UNAVAILABLE:=0}"

already_linked() {  # <source> <target>
  [ -L "$2" ] || return 1
  [ "$(readlink "$2")" = "$1" ]
}

same_content() {  # <source> <target>
  [ -e "$2" ] || return 1
  if [ -d "$1" ]; then
    [ -d "$2" ] || return 1
    diff -r -q "$1" "$2" >/dev/null 2>&1
  else
    [ -f "$2" ] || return 1
    cmp -s "$1" "$2"
  fi
}

backup_existing() {  # <target>
  if [ -e "$1" ] || [ -L "$1" ]; then
    mv "$1" "$1.bak-$STAMP"
    note "  backed up   $1.bak-$STAMP"
  fi
}

install_path() {  # <source> <target>
  local src="$1" dst="$2"
  if [ "$MODE" = "link" ] && already_linked "$src" "$dst"; then
    note "  unchanged   $dst  (link)"
    return 0
  fi
  if [ "$MODE" = "copy" ] && ! [ -L "$dst" ] && same_content "$src" "$dst"; then
    note "  unchanged   $dst  (copy)"
    return 0
  fi
  backup_existing "$dst"
  if [ "$MODE" = "link" ]; then
    ln -s "$src" "$dst"
    note "  link        $dst  ->  $src"
  else
    cp -R "$src" "$dst"
    note "  copy        $dst"
  fi
}

install_path "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"

# Only *.md -- rules/README.txt is documentation for a human and is not a rule.
for f in "$SRC"/rules/*.md; do
  [ -e "$f" ] || continue
  install_path "$f" "$DEST/rules/$(basename "$f")"
done

# One directory at a time: anything else already in ~/.claude/skills survives.
for d in "$SRC"/skills/*/; do
  [ -d "$d" ] || continue
  install_path "${d%/}" "$DEST/skills/$(basename "${d%/}")"
done

printf '\nInstalled into %s (mode: %s)\n\n' "$DEST" "$MODE"
if [ "${#REPORT[@]}" -gt 0 ]; then
  printf '%s\n' "${REPORT[@]}"
fi

if [ "$SYMLINKS_UNAVAILABLE" = "1" ]; then
  cat <<'NOSYM'

Symlinks are not available here, so everything above was COPIED.
A copy does not track edits to this repository -- re-run setup.sh after pulling.
On Git Bash for Windows, real symlinks need Developer Mode (or an elevated shell)
and MSYS=winsymlinks:nativestrict in the environment.
NOSYM
fi

cat <<'TAIL'

Not installed:
  rules/README.txt   documentation, not a rule -- a .md file there would load as one

settings.json was not touched, and this script will never touch it: it holds live
state -- enabled plugins, MCP servers, permission grants -- that a script has no
business merging. Add by hand if wanted, in ~/.claude/settings.json:

  "tui": "fullscreen",
  "autoUpdatesChannel": "latest"
TAIL
