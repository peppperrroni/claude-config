#!/usr/bin/env bash
# Install this repository's Claude Code layer into ~/.claude.
# Symlinks by default, so editing the repository edits the live config.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WANT="link"
PRUNE=0
REPORT=()

usage() {
  cat <<'USAGE'
usage: setup.sh [--copy] [--prune]

  --copy     install copies instead of symlinks. Copies do not track edits to
             this repository -- re-run setup.sh after pulling.
  --prune    delete entries this installer wrote earlier that no longer exist
             in the source. Without it, stale entries are only reported.

Installs into $CLAUDE_HOME if set, otherwise ~/.claude.
Never writes settings.json; prints what to add by hand instead.
Safe to re-run: anything already current is left alone.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --copy)    WANT="copy" ;;
    --prune)   PRUNE=1 ;;
    -h|--help) usage; exit 0 ;;
    *)         printf 'setup.sh: unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

note() { REPORT+=("$1"); }

mkdir -p "$DEST" "$DEST/rules" "$DEST/skills"
DEST="$(cd "$DEST" && pwd)"
MANIFEST="$DEST/.claude-config-manifest"

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

# ---------------------------------------------------------------------------
# Manifest. Entries are paths relative to $DEST and identical to the path
# relative to $SRC -- the two trees mirror each other, so one entry locates
# both. setup.ps1 reads and writes the same file, hence the CR tolerance.
# ---------------------------------------------------------------------------

# Nothing below is ever installed, so a manifest entry naming one is corruption,
# not a record. Prune refuses them even if the file is edited by hand.
safe_entry() {  # <entry>
  local e="$1"
  [ -n "$e" ] || return 1
  case "$e" in
    /*|\\*|[A-Za-z]:*)                                            return 1 ;;
    settings.json|settings.local.json|.credentials.json)           return 1 ;;
    .claude-config-manifest)                                       return 1 ;;
  esac
  case "/$e/" in
    */../*) return 1 ;;
  esac
  return 0
}

read_manifest() {
  [ -f "$MANIFEST" ] || return 0
  tr -d '\r' < "$MANIFEST" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                                 -e '/^#/d' -e '/^$/d'
}

write_manifest() {  # entries on stdin
  {
    printf '%s\n' '# Written by claude-config setup. -Prune / --prune reads this to find'
    printf '%s\n' '# entries that no longer exist in the source. Do not edit by hand.'
    sort -u
  } > "$MANIFEST"
}

remove_installed() {  # <target>
  # Delete the link, never through it: `rm -rf` on a symlink to a directory
  # removes the link, but only because the trailing slash is absent -- keep the
  # branch explicit so nobody "tidies" a slash back in.
  if [ -L "$1" ]; then rm -f "$1"
  elif [ -d "$1" ]; then rm -rf "$1"
  else rm -f "$1"
  fi
}

INSTALLED=()
install_entry() {  # <relative path>
  install_path "$SRC/$1" "$DEST/$1"
  INSTALLED+=("$1")
}

install_entry "CLAUDE.md"

# Only *.md -- rules/README.txt is documentation for a human and is not a rule.
for f in "$SRC"/rules/*.md; do
  [ -e "$f" ] || continue
  install_entry "rules/$(basename "$f")"
done

# One directory at a time: anything else already in ~/.claude/skills survives.
for d in "$SRC"/skills/*/; do
  [ -d "$d" ] || continue
  install_entry "skills/$(basename "${d%/}")"
done

# ---------------------------------------------------------------------------
# Stale entries. The manifest is the union of what was installed before and what
# was installed just now: rewriting it with only the current set would erase the
# record of the very entries prune exists to find.
# ---------------------------------------------------------------------------

TRACKED=()
while IFS= read -r line; do
  safe_entry "$line" && TRACKED+=("$line")
done < <(read_manifest; printf '%s\n' "${INSTALLED[@]}")

KEEP=()
STALE=()
seen=""
for entry in ${TRACKED[@]+"${TRACKED[@]}"}; do
  case "$seen" in *"|$entry|"*) continue ;; esac
  seen="$seen|$entry|"

  if [ -e "$SRC/$entry" ]; then KEEP+=("$entry"); continue; fi

  target="$DEST/$entry"
  # Already gone: nothing to clean, and no reason to keep reporting it.
  [ -e "$target" ] || [ -L "$target" ] || continue

  STALE+=("$entry")
done

for entry in ${STALE[@]+"${STALE[@]}"}; do
  target="$DEST/$entry"
  if [ "$PRUNE" = "1" ]; then
    remove_installed "$target"
    note "  pruned      $target"
  else
    KEEP+=("$entry")
    note "  stale       $target  (gone from source; --prune removes it)"
  fi
done

printf '%s\n' ${KEEP[@]+"${KEEP[@]}"} | write_manifest

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

if [ "${#STALE[@]}" -gt 0 ] && [ "$PRUNE" != "1" ]; then
  cat <<'STALE_NOTE'

Stale entries above were installed by an earlier run and are gone from the
source. Re-run with --prune to delete them. Nothing outside the manifest is
ever considered, so skills linked here from elsewhere are not at risk.
STALE_NOTE
fi

cat <<'TAIL'

Not installed:
  rules/README.txt   documentation, not a rule -- a .md file there would load as one
  templates/         copied into a new project by hand; see README

settings.json was not touched, and this script will never touch it: it holds live
state -- enabled plugins, MCP servers, permission grants -- that a script has no
business merging. Add by hand if wanted, in ~/.claude/settings.json:

  "tui": "fullscreen",
  "autoUpdatesChannel": "latest"
TAIL
