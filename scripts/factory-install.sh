#!/usr/bin/env bash
# Installs the factory into another repo, or updates a repo that already has it. Safe to re-run.
#
# usage: scripts/factory-install.sh [--check] [--prune] [--force] <path-to-your-repo>
#
#   --check   change nothing; list what an install or update would do. Exits 1 if anything would change.
#   --prune   also delete factory files in the target that this package no longer ships
#   --force   overwrite factory files that have uncommitted changes in the target
#
# Two kinds of file:
#   factory files  come from this package and are replaced on every run. Don't edit them in your
#                  repo; put team rules in CLAUDE.md or .claude/rules/audit-rulebook.md instead.
#   repo files     hold your repo's own values (board number, other hooks). They are added when
#                  missing and never overwritten.
set -euo pipefail

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "factory-install: $1" >&2; exit 2; }

CHECK=0 PRUNE=0 FORCE=0 TARGET=""
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    --prune) PRUNE=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option $arg (see --help)" ;;
    *) [ -z "$TARGET" ] || die "give one target repo, not several"; TARGET="$arg" ;;
  esac
done
[ -n "$TARGET" ] || { usage >&2; exit 2; }
[ -d "$TARGET" ] || die "$TARGET is not a directory"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$(cd "$TARGET" && pwd)"
[ "$TARGET" != "$SRC" ] || die "the target is the factory package itself"
git -C "$TARGET" rev-parse --show-toplevel >/dev/null 2>&1 || die "$TARGET is not a git repository"
[ "$(git -C "$TARGET" rev-parse --show-toplevel)" = "$TARGET" ] || die "$TARGET is not the root of its repository"

FACTORY_GLOBS=".claude/commands/factory/*.md .claude/agents/factory-*.md .claude/factory/*.md .claude/skills/factory/SKILL.md .claude/hooks/factory-guard.sh"
REPO_FILES=".claude/settings.json .github/workflows/factory-board.yml"
VERSION_FILE=".claude/factory/VERSION"

# Unquoted on purpose: the globs expand inside the given root.
list() { (cd "$1" && for f in $FACTORY_GLOBS; do [ -f "$f" ] && echo "$f"; done; true); }
dirty() { [ -n "$(git -C "$TARGET" status --porcelain -- "$1" 2>/dev/null)" ]; }
put() { mkdir -p "$TARGET/$(dirname "$1")"; cp "$SRC/$1" "$TARGET/$1"; case "$1" in *.sh) chmod +x "$TARGET/$1" ;; esac; }

package_version="$(git -C "$SRC" log -1 --format='%h %cs' 2>/dev/null || echo unknown)"
installed_version="$(cat "$TARGET/$VERSION_FILE" 2>/dev/null || echo none)"

added=0 updated=0 same=0 blocked=0 kept=0 stale=0

echo "Factory package:  $package_version  ($SRC)"
echo "Installed in repo: $installed_version  ($TARGET)"
echo

for f in $(list "$SRC"); do
  if [ ! -f "$TARGET/$f" ]; then
    echo "  add      $f"; added=$((added + 1))
    [ "$CHECK" = 1 ] || put "$f"
  elif cmp -s "$SRC/$f" "$TARGET/$f"; then
    same=$((same + 1))
  elif dirty "$f" && [ "$FORCE" = 0 ]; then
    echo "  BLOCKED  $f  (uncommitted changes in your repo; commit or stash them, or pass --force)"
    blocked=$((blocked + 1))
  else
    echo "  update   $f"; updated=$((updated + 1))
    [ "$CHECK" = 1 ] || put "$f"
  fi
done

for f in $REPO_FILES; do
  if [ ! -f "$TARGET/$f" ]; then
    echo "  add      $f  (yours to edit from here on)"; added=$((added + 1))
    [ "$CHECK" = 1 ] || put "$f"
  elif cmp -s "$SRC/$f" "$TARGET/$f"; then
    same=$((same + 1))
  else
    echo "  keep     $f  (your repo's own version; compare with the package's by hand)"; kept=$((kept + 1))
  fi
done

for f in $(list "$TARGET"); do
  [ "$f" = "$VERSION_FILE" ] && continue
  if [ ! -f "$SRC/$f" ]; then
    stale=$((stale + 1))
    if [ "$PRUNE" = 1 ] && [ "$CHECK" = 0 ]; then
      rm "$TARGET/$f"; echo "  remove   $f"
    else
      echo "  stale    $f  (not in the package any more; --prune removes it)"
    fi
  fi
done

if [ -f "$TARGET/.claude/settings.json" ] && ! grep -q 'factory-guard.sh' "$TARGET/.claude/settings.json"; then
  echo
  echo "  NOTE     .claude/settings.json doesn't register the guard hook. /factory:setup merges it in,"
  echo "           or copy the PreToolUse entry from $SRC/.claude/settings.json."
fi

changes=$((added + updated))
[ "$PRUNE" = 1 ] && changes=$((changes + stale))

echo
echo "$added to add, $updated to update, $same unchanged, $kept kept, $stale stale, $blocked blocked."

if [ "$CHECK" = 1 ]; then
  if [ $((changes + blocked)) -gt 0 ]; then
    echo "Not up to date. Run without --check to apply."
    exit 1
  fi
  echo "Up to date."
  exit 0
fi

# The version is recorded only when every factory file matches the package.
[ "$blocked" = 0 ] || { echo "Some files were left alone, so the repo is on a mix of versions; see BLOCKED above."; exit 1; }

if [ "$changes" -gt 0 ] || [ ! -f "$TARGET/$VERSION_FILE" ]; then
  mkdir -p "$TARGET/$(dirname "$VERSION_FILE")"
  echo "$package_version" > "$TARGET/$VERSION_FILE"
fi

echo
if [ "$changes" = 0 ]; then
  echo "Nothing to do: the repo already has this version."
elif [ "$installed_version" = none ] && [ "$updated" = 0 ]; then
  cat <<EOF
Installed. Next, in $TARGET:
  1. Commit the new files on a branch and merge it to the base branch.
     Cloud sessions clone from GitHub, so they only see what's merged.
  2. Run /factory:setup in Claude Code. It finds and checks the repo's commands,
     writes the CLAUDE.md sections, creates the labels and fills in the board workflow.
EOF
else
  cat <<EOF
Updated. Next, in $TARGET:
  1. Read the change:  git diff
     Anything you had edited in a factory file is replaced. Move team rules to CLAUDE.md
     or .claude/rules/audit-rulebook.md, and send real improvements upstream.
  2. Commit on a branch and merge it to the base branch.
  3. Run /factory:setup --check in Claude Code to see any new setting the update expects.
EOF
fi
