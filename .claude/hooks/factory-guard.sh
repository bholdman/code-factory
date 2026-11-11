#!/usr/bin/env bash
# PreToolUse guard for Bash: agents never merge PRs, force-push, push to main, or delete branches.
# Reads the hook's JSON on stdin. Exit 2 blocks the command and shows Claude the reason.
# This is a speed bump; the branch ruleset on GitHub is the real gate.
input=$(cat)
block() { echo "factory-guard: $1. A human merges factory work; escalate instead." >&2; exit 2; }

grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' <<<"$input" \
  && block "gh pr merge is blocked"
grep -Eq 'pulls/[0-9]+/merge' <<<"$input" \
  && block "merging through the API is blocked"
grep -Eq 'git[^"]*push[^"]*(--force|[[:space:]]-f([[:space:]]|")|[[:space:]]\+)' <<<"$input" \
  && block "force push is blocked"
grep -Eq 'git[^"]*push[^"]*([[:space:]:]|refs/heads/)(main|master|staging|develop|production)([[:space:]]|")' <<<"$input" \
  && block "pushing to a long-lived branch (main, staging, develop, production) is blocked"
grep -Eq 'git[^"]*push[^"]*(--delete|[[:space:]]-d[[:space:]]|[[:space:]]:[^[:space:]"])' <<<"$input" \
  && block "deleting a remote branch is blocked"
grep -Eq 'git/refs' <<<"$input" && grep -Eq '(-X|--method)[[:space:]]+(DELETE|PATCH)' <<<"$input" \
  && block "changing branch refs through the API is blocked"
exit 0
