#!/usr/bin/env bash
# Tests scripts/factory-install.sh against throwaway repos in a temp folder. usage: scripts/test-factory-install.sh
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; I="$SRC/scripts/factory-install.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok() { if [ "$1" = "$2" ]; then pass=$((pass+1)); echo "ok   $3"; else fail=$((fail+1)); echo "FAIL $3 (want $2, got $1)"; fi; }
has() { if grep -q -- "$2" <<<"$1"; then pass=$((pass+1)); echo "ok   $3"; else fail=$((fail+1)); echo "FAIL $3 (missing: $2)"; fi; }

mkdir -p "$W/fresh" && cd "$W/fresh" && git init -q . && git config user.email t@example.com && git config user.name t && echo hi > README.md && git add . && git commit -qm init

out=$("$I" --check "$W/fresh"); ok $? 1 "check on a repo without the factory exits 1"
has "$out" "add      .claude/commands/factory/build.md" "check lists files to add"
[ ! -e "$W/fresh/.claude" ]; ok $? 0 "check changed nothing"

out=$("$I" "$W/fresh"); ok $? 0 "fresh install exits 0"
has "$out" "Installed. Next" "fresh install prints install next steps"
count() { (cd "$1" && ls .claude/commands/factory/*.md .claude/agents/factory-*.md .claude/factory/*.md | wc -l | tr -d ' '); }
ok "$(count "$W/fresh")" "$(count "$SRC")" "every command, agent and reference file installed"
[ -x "$W/fresh/.claude/hooks/factory-guard.sh" ]; ok $? 0 "guard hook is executable"
[ -f "$W/fresh/.claude/settings.json" ] && [ -f "$W/fresh/.github/workflows/factory-board.yml" ]; ok $? 0 "repo files added when missing"
[ -f "$W/fresh/.claude/factory/VERSION" ]; ok $? 0 "version recorded"
[ ! -e "$W/fresh/scripts" ] && [ "$(cat "$W/fresh/README.md")" = hi ]; ok $? 0 "README and scripts not copied"
(cd "$W/fresh" && git add -A && git commit -qm factory)

out=$("$I" "$W/fresh"); ok $? 0 "second run exits 0"
has "$out" "Nothing to do" "second run is a no-op"
"$I" --check "$W/fresh" >/dev/null; ok $? 0 "check on an up-to-date repo exits 0"
[ -z "$(git -C "$W/fresh" status --porcelain)" ]; ok $? 0 "no-op run leaves the tree clean"

# committed local edit to a factory file, a customised repo file, and a stale factory file
cd "$W/fresh" && echo "local tweak" >> .claude/commands/factory/plan.md && echo "# mine" >> .github/workflows/factory-board.yml && echo old > .claude/agents/factory-old-agent.md && echo '{}' > .claude/settings.json && git add -A && git commit -qm local
out=$("$I" --check "$W/fresh"); ok $? 1 "check sees a drifted factory file"
has "$out" "update   .claude/commands/factory/plan.md" "drifted factory file listed for update"
has "$out" "keep     .github/workflows/factory-board.yml" "customised repo file is kept"
has "$out" "stale    .claude/agents/factory-old-agent.md" "stale factory file reported"
has "$out" "doesn't register the guard hook" "missing hook registration noted"
out=$("$I" "$W/fresh"); ok $? 0 "update exits 0"
has "$out" "Updated. Next" "update prints update next steps"
cmp -s "$SRC/.claude/commands/factory/plan.md" "$W/fresh/.claude/commands/factory/plan.md"; ok $? 0 "factory file restored to the package's"
grep -q "# mine" "$W/fresh/.github/workflows/factory-board.yml"; ok $? 0 "customised repo file untouched"
[ "$(cat "$W/fresh/.claude/settings.json")" = '{}' ]; ok $? 0 "existing settings.json untouched"
[ -f "$W/fresh/.claude/agents/factory-old-agent.md" ]; ok $? 0 "stale file kept without --prune"
"$I" --prune "$W/fresh" >/dev/null; [ ! -f "$W/fresh/.claude/agents/factory-old-agent.md" ]; ok $? 0 "--prune removes the stale file"
(cd "$W/fresh" && git add -A && git commit -qm update)

# uncommitted edit is protected
cd "$W/fresh" && echo "wip" >> .claude/agents/factory-builder.md
out=$("$I" "$W/fresh"); ok $? 1 "uncommitted edit makes the run exit 1"
has "$out" "BLOCKED  .claude/agents/factory-builder.md" "uncommitted edit is reported as blocked"
grep -q wip "$W/fresh/.claude/agents/factory-builder.md"; ok $? 0 "uncommitted edit is not overwritten"
"$I" --force "$W/fresh" >/dev/null; ok $? 0 "--force exits 0"
cmp -s "$SRC/.claude/agents/factory-builder.md" "$W/fresh/.claude/agents/factory-builder.md"; ok $? 0 "--force overwrites it"

# bad targets
"$I" "$W/nope" >/dev/null 2>&1; ok $? 2 "missing directory is refused"
mkdir -p "$W/plain"; "$I" "$W/plain" >/dev/null 2>&1; ok $? 2 "non-git directory is refused"
"$I" "$W/fresh/.claude" >/dev/null 2>&1; ok $? 2 "a subdirectory of a repo is refused"
"$I" "$SRC" >/dev/null 2>&1; ok $? 2 "the package itself is refused"
"$I" >/dev/null 2>&1; ok $? 2 "no target is refused"
"$I" --help | grep -q "usage:"; ok $? 0 "--help prints usage"

echo; echo "$pass passed, $fail failed"; [ "$fail" = 0 ]
