# Factory conventions

Every `/factory:*` command reads this file first. It holds the rules they share, so each rule lives in one place.

## How work flows

1. `/factory:plan` writes the plan, creates the issue's branch, commits the plan file to it, pushes, and links it from the issue.
2. A human reads the plan and adds `factory:ready`.
3. `/factory:build` checks out that branch, reads the plan file, builds, reviews, and opens the PR from the same branch.
4. A human reviews the PR. Findings on it, from people or review bots, go back through the builder and a reviewer before they are pushed.
5. A human merges.

The branch carries the plan and the code together. The issue carries the conversation: the plan link, review rounds, decisions, and any human notes. Anyone on any device can open the issue and see where things stand. Only the orchestrating command writes to GitHub; subagents return text.

## Branch and plan file

- **Branch:** `factory/<n>-<slug>`, where `<slug>` is 3–5 kebab-case words describing the work, such as `factory/41-csv-invoice-export`. If CLAUDE.md sets `Factory branch:` (for example `{number}-{slug}`), use that format instead.
- **Plan file:** `plans/<n>-<slug>.md` in the repo's root `plans/` folder on that branch. CLAUDE.md can change the folder with `Factory plan dir:` and the file name with `Factory plan file:` (for example `{number}-{slug}.md`). It stays in the PR and merges with the code, so the plan is kept next to the change it explains.
- **Design snapshot:** when the plan includes design, `/factory:design` links the design options from the plan's `### Design` section, and copies the chosen option into `plans/<n>-<slug>-design/` on the branch. Build works from that copy, because builders and cloud sessions may not be able to open the design.
- **The plan file is the plan.** Humans change it by editing the file on the branch. Comments on the issue that don't start with a factory heading are human notes: `/factory:build` reads them as clarifications and escalates if one contradicts the plan. A decision a human makes after approving the plan (during the build, or in PR review) is added to the file under `### Changes after approval`, so the plan that merges matches the code.
- **The factory branch wins.** A session may have been started on another branch, or told to use one of its own and to open draft PRs. Running a factory command is the instruction to use the factory's branch and PR rules for that work.

## Stage labels

Move an issue by adding the new label and removing the old one.

| Label | Meaning | Set by |
|---|---|---|
| `factory:planned` | Plan pushed, waiting for a human | `/factory:plan` |
| `factory:ready` | Plan approved, OK to build | A human, or `/factory:plan` when the human approves in the session |
| `factory:building` | Build running | `/factory:build` |
| `factory:in-review` | PR open, waiting for a human | `/factory:build` |
| `factory:needs-human` | Blocked on a human decision | Any command, on escalation |

A closed issue carries no stage label. `/factory:build` removes `factory:in-review` when the PR merges, and `/factory:status` lists any that were left behind.

## Comment headings

Factory comments start with one of these exact headings, so humans and later sessions can find them, and so human notes can be told apart:

- `## Factory plan`
- `## Factory review — round N` (after the PR opens: `## Factory review — after PR, round N`)
- `## Factory decision`

## Asking a human

When a person is in the session, every question to them goes through the AskUserQuestion tool (the popup). Never write a question in prose and wait for a typed reply. Prose questions get missed in a long transcript, and a popup with choices takes one click to answer.

- **Give choices.** Offer 2–4 suggested answers, each with a one-line consequence. Put your recommendation first and mark it "(Recommended)". The popup adds "Other" for free text, so a question with no natural choices (a URL, a handle) still goes through it, with the likeliest answers as options.
- **Make it stand alone.** The person may see only the dialog, not the text before it. Name the issue, say what you found, and say what each choice leads to.
- **Batch.** Ask related questions in one call (up to four), not one popup after another.
- **A missing argument is a question too.** When a command needs an issue or PR number it wasn't given, ask with the popup and offer the likeliest candidates, such as the issues in the stage that command works on.
- **Ask only what a human must decide.** A fact you can read from the repo, the issue or CLAUDE.md isn't a question. Neither is "shall I continue?" when the command already says what comes next.
- **Record the answer.** An answer that changes a plan or settles an escalation is also written to the issue: in the plan comment, or in a `## Factory decision` comment that starts "Answered in session by @<login>". The issue should still tell the whole story.

Nobody is in the session in a batch or scheduled run, or when the popup isn't available or goes unanswered. Then the question goes on the issue as a `## Factory decision` comment and the issue moves to `factory:needs-human`. Subagents never ask a human: they return the question, and the orchestrating command asks it.

## Keep it simple

Take the simplest approach that meets the acceptance criteria. Never get there by giving up security or behaviour the issue asks for: a smaller change that leaves a hole or drops a criterion isn't simpler, it's unfinished.

- **Look for the one place first.** Most requests can be met where the code already sends everyone (one gate, one page, one service). Plan and build there before putting the same check in many files.
- **Count the cost.** An approach costs the files it touches, the existing tests it makes you change, and the new things it adds for the next reader (a concern, a helper, a second way to do something the repo already does). Needing to edit many existing tests is a sign the approach is wider than the request.
- **Tell the developer before complexity grows.** When a decision would make the work significantly bigger (about twice the files, a size class up, existing tests rewritten, or a new mechanism beside one the repo has), stop and say so before doing it: what the simple version covers, what the bigger one adds, and what each costs. In a plan that is an open question. In a build it is BLOCKED with that question, not a deviation.
- **Put the cost in the question.** When you offer a human options, give each one's size beside its consequence (files, existing tests that change), so nobody picks the expensive one without seeing its price. Recommend the smaller option unless it costs security or required behaviour, and say which when it does.

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
| Open a PR | `gh api repos/$REPO/pulls -f title=<t> -f head=<branch> -f base=$BASE_BRANCH -F draft=false -F body=@<file>` (factory PRs are never drafts) |
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

1. Read the repo's `CLAUDE.md`: the "Commands the factory runs" section, any project rules, any orientation or review-hotspot notes, and `## Factory lessons` (written by `/factory:retro` from earlier builds). Project rules and lessons bind with the same force as the factory's own rules. If the commands section is missing, say so in your final report, because work without known test commands is much weaker.
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

If `/tmp/factory-<n>/wt` already exists, an earlier command in this checkout kept it. Reuse it; don't add it again, and never reset it, because it may hold commits or files that weren't pushed. Look at `git -C /tmp/factory-<n>/wt status`, fetch, and bring in anything `origin/<branch>` has that the worktree lacks with a merge (`git -C /tmp/factory-<n>/wt merge origin/<branch>`).

Work, commit and push from inside the worktree (`git -C /tmp/factory-<n>/wt push -u origin <branch>`). Record the diff base with `BASE=$(git -C /tmp/factory-<n>/wt merge-base HEAD origin/$BASE_BRANCH)`.

Before running anything in a new worktree:

1. **Prep it.** A fresh worktree holds only tracked files. Run CLAUDE.md's `Factory worktree prep:` command if it has one. It builds what the tests need and git doesn't track, such as compiled assets or generated files.
2. **Check the services** CLAUDE.md lists are up. In a cloud session they stop when the container idles between turns, so check again before each test run and restart them when needed.

A run where hundreds of unrelated tests fail at once, or that fails on connection or missing-file errors, is an environment problem. Read the first error, fix the environment and run again before treating any of it as a test failure. Say the same in every subagent's brief.

Keep the worktree until the work on the branch is over, then remove it with `git worktree remove /tmp/factory-<n>/wt`. For `/factory:plan` that is when the plan is pushed or approved. For `/factory:build` it is when the PR merges or closes, or the build escalates.

## Running subagents

- Launch them in the background and tell the human in one line what is running, so they can follow along and interject.
- Brief each one completely; it knows only what the brief says. Give it paths, not pasted contents.
- Check what comes back before building on it: the commits exist, nothing is left uncommitted, and the test log shows what the report claims.
- Push the branch after every stage that adds commits. A cloud container can restart in the middle of a build. The exception is a fix round after the PR opens: it is pushed once its review passes, so the open PR never holds an unreviewed commit.
- If a subagent is interrupted, look at the worktree before relaunching, and tell the new one what was left behind.
- If a subagent can't start because its model isn't available or is rate-limited, launch it again with the Agent tool's `model` option set to the next model down (`fable`, then `opus`, then `sonnet`); that option overrides the agent's own `model:` line. Say in the report which agents ran on a fallback. Don't step down for any other kind of failure.
- Each agent ends its commits with the attribution its own session gives it. A trailer that differs from the orchestrator's isn't an error.

## Choosing reviewers

Run only the reviewers a change needs. That saves time and usage and keeps the signal high. List changed files with `git diff --name-only $BASE...HEAD`, then:

- `factory-reviewer-code`: always. For a plan sized M or larger, or a change that touches money, webhooks, background jobs, migrations or permissions, run it on the strongest model the session offers (the Agent tool's `model` option) instead of its default. Those are the changes where later review has kept finding what the build's review missed.
- `factory-reviewer-security`: auth, sessions, permissions, payments, personal data, secrets or config, database queries, file uploads, outbound HTTP calls, dependency manifests or lockfiles, CI workflows, infrastructure.
- `factory-reviewer-ux` and `factory-reviewer-ui`: a new or reworked screen or flow gets both. A small change to an existing screen (copy, one element, a style tweak) gets `factory-reviewer-ui` alone, briefed to check the copy and the states as well as the look.
- When unsure whether a reviewer applies, include it.

Give each reviewer the issue, the plan file path, the worktree path, `$BASE`, the round number, the CLAUDE.md commands, and the previous round's findings for its area. Tell each what the builder reported as deviations, so it verifies them instead of rediscovering them. Run them in parallel, and give each reviewer that starts the app its own port. The plan file and the design snapshot aren't code; reviewers skip them, except that the UI reviewer compares the built screens to the snapshot.

Reviewers run the tests for the areas the change touches. The approver runs the full suite once, so a round doesn't pay for it several times over.

## Shared references

- Planning procedure and plan template: `.claude/factory/planning.md`
- Review rules: `.claude/rules/audit-rulebook.md` if the repo has one (the team's own rulebook), otherwise `.claude/factory/audit-rulebook.md`
- Lessons from earlier builds: the `## Factory lessons` section of CLAUDE.md, proposed by `/factory:retro` and merged by a human. It belongs to the repo, not the factory package, so updates never overwrite it.

## Settings in CLAUDE.md

All optional, and `/factory:setup` fills them in. They live under a "Factory settings" heading in `CLAUDE.md`:

| Key | Default | Used by |
|---|---|---|
| `Factory base branch:` | the repo's default branch | where factory branches start and PRs target |
| `Factory branch:` | `factory/{number}-{slug}` | `/factory:plan` |
| `Factory plan dir:` | `plans` | `/factory:plan`, `/factory:build` |
| `Factory plan file:` | `{number}-{slug}.md` | `/factory:plan` |
| `Factory worktree prep:` | none | a command run once in each new worktree, for what the tests need that git doesn't track (compiled assets, generated files) |
| `Factory design system:` | the app's own components and styles | `/factory:design`: a claude.ai design system link to start designs from, or a note on which existing components and styles to match |
| `Factory reviewers:` | none | GitHub handles to request on factory PRs (the PR's author is skipped) |
| `MAX_INLINE` | 15 | `/factory:pr-audit` inline-comment cap |
| `APP_GLOBS`, `TEST_GLOBS`, `MIGRATION_GLOBS`, `FRONTEND_GLOBS` | inferred from the repo layout | `/factory:pr-audit`, reviewer selection |
| Rulebook thresholds | rulebook defaults | reviewers, `/factory:pr-audit` |
