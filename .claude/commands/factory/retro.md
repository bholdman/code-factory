---
description: Factory — look back over recently finished factory issues, find what the plan or the build's review missed and later review caught, and propose lessons as a PR for a human to merge
argument-hint: "[--since YYYY-MM-DD | --last N] [--dry-run]"
disable-model-invocation: true
model: fable
---

# /factory:retro

Arguments: `$ARGUMENTS`
- `--since YYYY-MM-DD`: look at factory issues closed on or after that date.
- `--last N`: look at the N most recently closed factory issues.
- Neither: everything closed since the window of the last merged retro PR ended, or the last 30 days if there has been none.
- `--dry-run`: report the lessons in chat and change nothing.

Read `.claude/factory/conventions.md` first. It defines the labels, comment headings, how to ask a human, REST-only GitHub calls, worktrees, running subagents and hard limits this command relies on.

The factory doesn't remember earlier builds. Every run starts from the repo's files, so the only way a build teaches the next one is a line someone writes into those files. This command finds the lines worth writing. A human merges them, so one odd build can't teach the factory a bad habit.

## What it may change

Only files that belong to the repo, because the installer replaces the factory's own files on every update:

- **`CLAUDE.md`, section `## Factory lessons`.** Every factory agent reads CLAUDE.md, so a lesson here reaches the plan writer, the builder and the reviewers. Create the section if it's missing, just before `## Factory settings`.
- **`.claude/rules/audit-rulebook.md`**, only if the repo already has one. Never create it: creating it switches every reviewer off the starter rulebook for good, which is the human's call. Without it, review lessons go in `## Factory lessons` under "Review", and reviewers apply CLAUDE.md rules with the same force.

Never edit `.claude/factory/`, `.claude/commands/factory/`, `.claude/agents/factory-*.md`, the factory skill or the guard hook. A lesson that can only be fixed there is a suggestion for the factory package: it goes in the PR body for a human to take upstream.

## 1. Choose the window

Set `REPO`, `DEFAULT` and `BASE_BRANCH` (conventions.md).

Find the last retro: the most recently merged PR whose head branch starts `factory/retro-`:

```bash
gh api "repos/$REPO/pulls?state=closed&base=$BASE_BRANCH&per_page=100" --paginate \
  -q '.[] | select(.merged_at != null and (.head.ref | startswith("factory/retro-"))) | [.merged_at, .number, .head.ref] | @tsv' | sort -r | head -1
```

Its body holds a line `**Window:** <from> → <to>`. Without `--since` or `--last`, start the new window the day after that `<to>`; with no earlier retro, start 30 days ago. The window ends today.

## 2. Collect the record

Find the issues closed in the window that went through the factory: those with a `## Factory plan` comment. Closed issues carry no stage label, so look for the comment:

```bash
gh api "repos/$REPO/issues?state=closed&since=<from>T00:00:00Z&per_page=100" --paginate \
  -q '.[] | select(.pull_request == null and .closed_at >= "<from>") | .number'
```

For each candidate, read its comments and keep it only if one starts with `## Factory plan`. Also include open issues labeled `factory:needs-human` that were updated in the window: an escalation is a lesson too.

Fewer than 3 issues → say so and stop, unless the user passed `--last` or `--since`. A pattern needs more than one build to show itself.

For each kept issue, write one file `/tmp/factory-retro/<n>.md` with:

1. The issue title, body, labels and closed date.
2. Every comment, in order, with its author and date. The factory headings (`## Factory plan`, `## Factory review — round N`, `## Factory review — after PR, round N`, `## Factory decision`) are the spine, and human notes between them matter just as much.
3. The PR for the plan's branch (`state=all`), if there is one: its body (deviations, follow-ups, reviews), its reviews (`pulls/<pr>/reviews`), its review comments (`pulls/<pr>/comments`) and its issue comments, each with the author and whether it's a bot.
4. The plan file's `### Changes after approval` section, read from the merged base branch, or from the branch if it never merged.

Keep the files whole: the analyst judges what matters. Write `/tmp/factory-retro/index.md` listing each issue with its number, title, size from the plan comment, number of review rounds, and whether it escalated.

Read the current `## Factory lessons` section of CLAUDE.md, and the team rulebook if there is one, so the analyst can see what's already written down.

## 3. Analyse

Launch one `factory-retro-analyst` in the background and tell the human in one line what's running. Give it:

- the window and `/tmp/factory-retro/`;
- the path to CLAUDE.md, and to `.claude/rules/audit-rulebook.md` if it exists (otherwise to `.claude/factory/audit-rulebook.md`, read-only, so it doesn't propose a rule the starter already has);
- `.claude/factory/planning.md` and the agent files under `.claude/agents/`, read-only, so it knows what each stage is already told to do.

It runs on Fable, for the same reason planning does: one run, read by a human, and every later build inherits what it gets wrong. If it can't start on Fable, relaunch it on Opus (conventions.md, "Running subagents") and say so in the report.

It returns the proposed edits, each with its evidence, plus suggestions for the factory package and unfiled follow-ups. Check its citations before using them: every issue, comment or PR it cites must be in the collected files, and a lesson must cite at least the issues the bar below requires. Drop any lesson that fails.

**The bar for a lesson.** Two or more issues show the same miss, or one issue shows a blocker or major that only surfaced after the PR opened, or that a human caught. A miss caught in round 1 by the right reviewer is the process working, not a lesson.

## 4. Ask (with a person in the session)

Show, in about 15 lines: the window, the number of issues, each proposed lesson in one line with the issues it cites, and the factory-package suggestions. Then ask with the popup (conventions.md, "Asking a human"):

- "Open a PR with these lessons?" with **Open the PR (Recommended)**, **Report only, change nothing**, and, when there are more than four lessons, **Let me pick which**.
- On "Let me pick which", ask a multi-select question listing the lessons, up to four per question and up to four questions in one call.

With nobody in the session, open the PR with every lesson that met the bar. The human merges or edits it, so nothing changes until they do.

`--dry-run` or "Report only": skip to step 6.

## 5. Branch, edit, PR

1. Open a worktree on a new branch `factory/retro-<YYYY-MM-DD>` (today's date) from `origin/$BASE_BRANCH`, as conventions.md describes. If that branch already exists on `origin` with an open PR, a retro already ran today: update that branch instead of starting another.
2. Apply the edits:
   - **`## Factory lessons`**: grouped under `### Planning`, `### Building` and `### Review`. Each lesson is one bullet: the rule, said as an instruction, then the evidence in parentheses with the issue numbers and the retro date, e.g. `(#2935, #2941; retro 2026-11-20)`. Merge a new lesson into an existing one when they say the same thing, and add the new evidence. Remove a lesson only if the analyst shows it's now covered by the rulebook or the factory package, and say so in the PR.
   - **Team rulebook**: add a rule under the matching § with the next free number, in the rulebook's own format, with the same evidence line.
   - Keep the section short. Past about 25 lessons, the agents start to skim; the analyst proposes merges or removals to stay under that.
3. Commit (`docs: factory retro <from> to <to>`) and push the branch.
4. Open the PR into `$BASE_BRANCH`, ready for review (`-F draft=false`), titled `Factory retro: <from> to <to>`. The body:

```markdown
**Window:** <from> → <to> · <n> issues · <n> lessons

## Lessons
<for each: the lesson as written, where it went (CLAUDE.md § or rulebook §x.y), and the evidence: issue links, the round that caught it, and which stage should have>

## Suggestions for the factory package
<changes that only the factory's own files can make, with the evidence. Take these to the code-factory repo; this PR doesn't touch them.> (or "None")

## Follow-ups nobody filed
<follow-ups listed in factory PR bodies with no issue found for them, each with the PR it came from> (or "None")

## Issues reviewed
<the index: number, title, size, rounds, escalated>
```

5. Request the `Factory reviewers:` from CLAUDE.md, leaving out the PR's author.

Don't post on the issues you read. The retro PR is the record, and the next retro finds its window there.

## 6. Report

In chat: the window, how many issues, the lessons (or "none met the bar"), the factory-package suggestions, the unfiled follow-ups, and the PR link if one opened. Name the model the analyst ran on. Remove the worktree once the PR is pushed. Suggest running a retro every few weeks, or after any build that took three review rounds or escalated.
