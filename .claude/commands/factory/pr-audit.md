---
description: Factory — review a pull request read-only against the audit rulebook (and its factory plan, if it has one) and post one COMMENT review
argument-hint: <pr-number-or-url>
disable-model-invocation: true
---

# /factory:pr-audit

PR: `$ARGUMENTS` (none → ask with the popup, offering the open PRs, factory PRs first)

Review a pull request the way a careful senior teammate would: read-only, grounded in the rulebook, and posted as one review. It works on teammates' PRs and on factory PRs. For a factory PR, it also checks the work against its approved plan and verifies the evidence the approver claimed.

Read `.claude/factory/conventions.md` first.

**Review-only.** Never edit files, run tests or hooks, approve, request changes, resolve threads, or change labels. Post exactly one review per run, always with `event: "COMMENT"`. GitHub lets a PR's author post a COMMENT review on their own PR, so this works on factory PRs opened under your account.

## Settings

Read these from the "Factory settings" section of CLAUDE.md, or use the defaults in conventions.md: `MAX_INLINE`, the four file globs, and any rulebook threshold overrides.

The rulebook is `.claude/rules/audit-rulebook.md` if the repo has one, otherwise `.claude/factory/audit-rulebook.md`.

## Phase 0 — Fetch and prepare

1. **The PR.** Resolve the number and set `REPO` (conventions.md). Fetch the metadata, files and diff with REST, since `gh pr` fails in cloud sessions:
   `gh api repos/$REPO/pulls/<n>`, `gh api repos/$REPO/pulls/<n>/files --paginate`, and `gh api repos/$REPO/pulls/<n> -H "Accept: application/vnd.github.diff"`.
   Keep the head SHA (`.head.sha`), because inline comments anchor to it.
2. **Categorize** the changed files with the globs: application, tests, migrations, frontend.
3. **Dedupe against earlier runs.** Fetch the PR's review comments (`gh api repos/$REPO/pulls/<n>/comments --paginate`) and find this command's earlier ones by the `<!-- factory-pr-audit` marker. Don't re-post a finding that matches an earlier one's path and rule (its line may have shifted); list it under "Previously reported, still open" instead. Comments without the marker are human comments, never duplicates. A marker is used instead of the comment author because cloud sessions post under your own GitHub account.
4. **Story link.** Find the issue from `Closes #N` in the body or the issue number in the branch name.
5. **Factory context.** It's a factory PR when the PR adds or changes a plan file in `plans/` (or the `Factory plan dir:` from CLAUDE.md) whose name contains the linked issue's number. Read the plan file at the head commit, and fetch the linked issue's `## Factory review` and `## Factory decision` comments. Leave the plan file out of the code audit; it isn't code.
6. **Token posture.** Audit from the diff hunks plus targeted context, such as the enclosing function or class via line-ranged reads. Read whole files only when a class-level judgment needs it. For large PRs (more than 15 changed application files), split file groups across read-only Explore subagents. Brief each with the rulebook path to read, its files and hunks, and this return format of about 30 lines: `FINDINGS path:line · rule · severity · named problem`. Merge their findings.

## Phase 1 — Audit

Read the rulebook first; never audit from memory. Check changed application files against §1, §2 and §4, migrations against §3, and application and test files against §5. A metric finding must name the actual problem, not just the number. Project rules and review hotspots in CLAUDE.md bind with the same force as the rulebook.

Factory PRs get three more checks:

- **Plan conformance:** every plan step shows up in the diff, changes outside the plan's scope fence are findings (Medium, unless trivial), and the plan file wasn't edited by the build.
- **Evidence:** for each acceptance criterion the PR body claims, confirm the named test exists and actually asserts that criterion. A claim the code doesn't back is High.
- **Review history:** blocker and major findings from the factory review rounds are resolved or explained.
- **Unreviewed commits:** list the commits pushed after the newest `## Factory review` comment on the issue. No factory reviewer saw them, so read them with the most care and name them in the summary.

## Phase 2 — Post the review

**Selection under the cap.** All High findings anchor inline first. Remaining slots, up to `MAX_INLINE`, go to the highest-impact Mediums. Everything else appears only in the summary tables. If the High findings alone exceed the cap, anchor the most consequential and say so in the summary.

**Line anchoring.** Inline comments can only anchor to lines present in the diff (`side: "RIGHT"` for additions). A finding on an unchanged line, such as a class-level judgment, can't anchor; put it in the summary with its `path:line` instead of letting the API call fail.

**Tone.** This is a teammate's work, so write observations and suggestions with reasons, never commands. Name the rule and why it matters here. Keep suggested fixes under 15 lines and mark them as suggestions. Format each inline comment like this:

```markdown
**[<Severity>] <Short title>**

<One paragraph: the specific problem and why it matters in this context.>

<Optional suggestion snippet.>

<!-- factory-pr-audit rule=<§x.y> -->
```

**Build and post.** Build the payload with a small Python script so JSON escaping can't break, with `commit_id` set to the head SHA, `event` set to `"COMMENT"`, the summary as `body`, and the inline comments as `comments` (`path`, `line`, `side`, `body`). Write it to `/tmp/factory-pr-audit-<n>.json`, then:

```bash
gh api repos/$REPO/pulls/<n>/reviews --method POST --input /tmp/factory-pr-audit-<n>.json
```

**Summary body:**

```markdown
<!-- factory-pr-audit summary -->
## Code audit — PR #<n> · Story: #<issue> (<project status, if known>)

| Severity | New | Previously reported |
|---|---|---|
| High | X | A |
| Medium | Y | B |
| Low | Z | — |

### Factory plan check
<!-- factory PRs only -->
| Check | Result |
|---|---|
| Plan steps in the diff | All, or which are missing |
| Changes outside the scope fence | None, or which |
| Criteria evidence holds | n of m, naming any that don't |
| Factory review findings resolved | Yes, or which aren't |
| Commits after the last factory review | None, or which (no factory reviewer saw these) |

### High
| File | Issue |
|---|---|
| `path:line` | <named problem> <mark [summary-only] if it couldn't anchor> |

### Medium
<same table>

### Low
<same table>

### Previously reported, still open
| File | Issue |
|---|---|

<One or two sentences: what the PR does well, and the main concerns.>
```

## Notes

- One review per run; re-runs dedupe instead of repeating.
- This command and `factory-reviewer-code` share the rulebook. Change rules in the rulebook, never in this file.
- In cloud sessions, `gh api` posts through Anthropic's GitHub proxy under your GitHub account. Use REST only; the proxy rejects GraphQL.
