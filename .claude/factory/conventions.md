# Factory conventions

Every `/factory:*` command reads this file first. It holds the rules they share, so each rule lives in one place.

## How work flows

1. `/factory:plan` writes the plan, creates the issue's branch, commits the plan file to it, pushes, and links it from the issue.
2. A human reads the plan and adds `factory:ready`.
3. `/factory:build` checks out that branch, reads the plan file, builds, reviews, and opens the PR from the same branch.
4. A human reviews and merges.

The branch carries the plan and the code together. The issue carries the conversation: the plan link, review rounds, decisions, and any human notes. Anyone on any device can open the issue and see where things stand. Only the orchestrating command writes to GitHub; subagents return text.

## Branch and plan file

- **Branch:** `factory/<n>-<slug>`, where `<slug>` is 3–5 kebab-case words describing the work, such as `factory/41-csv-invoice-export`. If CLAUDE.md sets `Factory branch:` (for example `{number}-{slug}`), use that format instead.
- **Plan file:** `plans/<n>-<slug>.md` in the repo's root `plans/` folder on that branch. CLAUDE.md can change the folder with `Factory plan dir:` and the file name with `Factory plan file:` (for example `{number}-{slug}.md`). It stays in the PR and merges with the code, so the plan is kept next to the change it explains.
- **Design snapshot:** when the plan includes design, `/factory:design` links the design options from the plan's `### Design` section, and copies the chosen option into `plans/<n>-<slug>-design/` on the branch. Build works from that copy, because builders and cloud sessions may not be able to open the design.
- **The plan file is the plan.** Humans change it by editing the file on the branch. Comments on the issue that don't start with a factory heading are human notes: `/factory:build` reads them as clarifications and escalates if one contradicts the plan.

## Stage labels

Move an issue by adding the new label and removing the old one.

| Label | Meaning | Set by |
|---|---|---|
| `factory:planned` | Plan pushed, waiting for a human | `/factory:plan` |
| `factory:ready` | Plan approved, OK to build | A human, or `/factory:plan` when the human approves in the session |
| `factory:building` | Build running | `/factory:build` |
| `factory:in-review` | PR open, waiting for a human | `/factory:build` |
| `factory:needs-human` | Blocked on a human decision | Any command, on escalation |

## Comment headings

Factory comments start with one of these exact headings, so humans and later sessions can find them, and so human notes can be told apart:

- `## Factory plan`
- `## Factory review — round N`
- `## Factory decision`

## Hard limits

Never merge a PR, never push to `main`, `master` or the base branch (such as `staging`), never force-push, never delete a branch. A human is the merge gate, and these are the ways an agent could skip it. The GitHub proxy in cloud sessions doesn't restrict which branches a push can update, so the repo's branch ruleset and the guard hook are what protect main. If the hook blocks you, don't look for a way around it; escalate instead.

## GitHub access: REST only

Use `gh api` with REST endpoints for every GitHub call. In cloud sessions the GitHub proxy rejects GraphQL, which includes `gh issue …`, `gh pr …` and `gh repo view`. REST works the same locally and in the cloud, so there's one code path. `gh` is pre-installed in cloud sessions and authenticates through the proxy (`GH_TOKEN` reads `proxy-injected`); locally it uses the user's login.

Set the repo once from the remote, since cloud clones can use a proxy URL that `gh`'s `{owner}/{repo}` placeholders don't resolve:

```bash
REPO=$(git remote get-url origin | sed -E 's#(\.git)?/?$##; s#.*[/:]([^/]+/[^/]+)$#\1#')
DEFAULT=$(gh api repos/$REPO -q .default_branch)
# PRs target the base branch: CLAUDE.md "Factory base branch:" if set (e.g. staging), else the default branch
BASE_BRANCH=<Factory base branch from CLAUDE.md, or $DEFAULT>
```

| Task | Call |
|---|---|
| Read an issue | `gh api repos/$REPO/issues/<n>` |
| Read its comments | `gh api repos/$REPO/issues/<n>/comments --paginate` |
| Post a comment | write the body to a file, then `gh api repos/$REPO/issues/<n>/comments -F body=@<file>` |
| Add a label | `gh api repos/$REPO/issues/<n>/labels -f "labels[]=factory:building"` |
| Remove a label | `gh api -X DELETE repos/$REPO/issues/<n>/labels/factory%3Aready` (encode `:` as `%3A`; a 404 means it wasn't there) |
| List issues with a label | `gh api "repos/$REPO/issues?state=open&labels=factory:planned&per_page=100" --paginate`, skipping items that have a `pull_request` key |
| Open a PR | `gh api repos/$REPO/pulls -f title=<t> -f head=<branch> -f base=$BASE_BRANCH -F body=@<file>` |
| Find a branch's PR | `gh api "repos/$REPO/pulls?head=${REPO%%/*}:<branch>&state=open"` |
| Request reviewers | `gh api repos/$REPO/pulls/<pr>/requested_reviewers -f "reviewers[]=<handle>"` |
| Read a PR | `gh api repos/$REPO/pulls/<pr>` |
| PR files | `gh api repos/$REPO/pulls/<pr>/files --paginate` |
| PR diff | `gh api repos/$REPO/pulls/<pr> -H "Accept: application/vnd.github.diff"` |
| PR review comments | `gh api repos/$REPO/pulls/<pr>/comments --paginate` |
| Post a review | `gh api repos/$REPO/pulls/<pr>/reviews --method POST --input <file.json>` |
| Your login | `gh api user -q .login` |

## The kanban board follows the labels

Each stage label has a column on the team's GitHub Project board, and the card moves when the label changes. Commands never touch the board directly: GitHub Projects can only be changed through GraphQL, which cloud sessions can't reach. Instead, the repo's `.github/workflows/factory-board.yml` Action runs whenever a factory label is added and moves the card, adding the issue to the board first if it isn't there. So setting the stage label is how every command moves the card, and the label change must always happen, even when nothing else changed. When the PR merges and `Closes #N` closes the issue, the board's own "Item closed" workflow moves the card to Done.

## Before you start

1. Read the repo's `CLAUDE.md`: the "Commands the factory runs" section, any project rules, and any orientation or review-hotspot notes. Project rules bind with the same force as the factory's own rules. If the commands section is missing, say so in your final report, because work without known test commands is much weaker.
2. Set `REPO`, `DEFAULT` and `BASE_BRANCH` as above, and check access with `gh api repos/$REPO -q .full_name`.
3. Keep large outputs (diffs, test logs, screenshots) in `/tmp/factory-<n>/` and pass subagents paths, not contents.
4. You're in a cloud session when `CLAUDE_CODE_REMOTE` is `true`. Push before a cloud session ends; unpushed cloud work is lost.

## Working on factory branches

Use a temporary worktree so the current checkout is never disturbed, locally or in the cloud:

```bash
git fetch origin
# new branch (plan):
git worktree add /tmp/factory-<n>/wt -b <branch> origin/$BASE_BRANCH
# existing branch (build, or re-plan):
git worktree add /tmp/factory-<n>/wt -B <branch> origin/<branch>
```

Work, commit and push from inside the worktree (`git -C /tmp/factory-<n>/wt push -u origin <branch>`). Remove it with `git worktree remove /tmp/factory-<n>/wt` when the command finishes. Record the diff base with `BASE=$(git -C /tmp/factory-<n>/wt merge-base HEAD origin/$BASE_BRANCH)`.

## Choosing reviewers

Run only the reviewers a change needs. That saves time and usage and keeps the signal high. List changed files with `git diff --name-only $BASE...HEAD`, then:

- `factory-reviewer-code`: always.
- `factory-reviewer-security`: auth, sessions, permissions, payments, personal data, secrets or config, database queries, file uploads, outbound HTTP calls, dependency manifests or lockfiles, CI workflows, infrastructure.
- `factory-reviewer-ux` and `factory-reviewer-ui`: any frontend change, meaning components, views, templates, styles, client-side scripts, or user-facing copy.
- When unsure whether a reviewer applies, include it.

Give each reviewer the issue, the plan file path, the worktree path, `$BASE`, the round number, the CLAUDE.md commands, and the previous round's findings for its area. Run them in parallel. The plan file and the design snapshot aren't code; reviewers skip them, except that the UI reviewer compares the built screens to the snapshot.

## Shared references

- Planning procedure and plan template: `.claude/factory/planning.md`
- Review rules: `.claude/rules/audit-rulebook.md` if the repo has one (the team's own rulebook), otherwise `.claude/factory/audit-rulebook.md`

## Settings in CLAUDE.md

All optional, and `/factory:setup` fills them in. They live under a "Factory settings" heading in `CLAUDE.md`:

| Key | Default | Used by |
|---|---|---|
| `Factory base branch:` | the repo's default branch | where factory branches start and PRs target |
| `Factory branch:` | `factory/{number}-{slug}` | `/factory:plan` |
| `Factory plan dir:` | `plans` | `/factory:plan`, `/factory:build` |
| `Factory plan file:` | `{number}-{slug}.md` | `/factory:plan` |
| `Factory design system:` | the app's own components and styles | `/factory:design`: a claude.ai design system link to start designs from, or a note on which existing components and styles to match |
| `Factory reviewers:` | none | GitHub handles to request on factory PRs (the PR's author is skipped) |
| `MAX_INLINE` | 15 | `/factory:pr-audit` inline-comment cap |
| `APP_GLOBS`, `TEST_GLOBS`, `MIGRATION_GLOBS`, `FRONTEND_GLOBS` | inferred from the repo layout | `/factory:pr-audit`, reviewer selection |
| Rulebook thresholds | rulebook defaults | reviewers, `/factory:pr-audit` |
