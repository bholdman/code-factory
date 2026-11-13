# Claude Code Software Factory

A set of Claude Code commands, subagents and hooks that turn GitHub issues into reviewed pull requests. You plan issues, approve the plans, and fire off builds in parallel cloud sessions you can watch from your phone. Specialist agents review every change for security, UX, UI and code quality, and a human always merges.

Drop this into a repo, commit it, and the `/factory:*` commands work in every Claude Code session on that repo: local, cloud, Desktop app, or phone.

- New to it: [Add it to a repo](#1-add-it-to-a-repo-20-min).
- Already using it: [Updating a repo that already has the factory](#updating-a-repo-that-already-has-the-factory).

## Requirements

- Claude Code with access to cloud sessions (Claude Code on the web), and the Claude GitHub app installed on the repo
- A GitHub repo with issues
- Optional: a GitHub Projects board, for the kanban automation
- Optional: the `gh` CLI on your laptop, for running commands locally

## How it works

1. **`/factory:plan 41`** plans the issue, creates its branch (`factory/41-csv-invoice-export`), commits the plan to the root `plans/` folder (`plans/41-csv-invoice-export.md`), pushes, and links the plan from the issue.
2. **You approve** by adding `factory:ready`. With one issue you can also answer its questions and approve right in the session.
3. **`/factory:build 41`** checks out that branch, reads the plan file, builds test-first, runs the reviewers, and opens the PR from the same branch.
4. **You review.** Findings on the PR, yours or a review bot's, go back through the builder and a reviewer before they're pushed, and are recorded on the issue.
5. **You merge.** The plan file merges with the code, so the plan stays next to the change it explains.

| Command | What it does |
|---|---|
| `/factory:setup [--check]` | Prepares the repo: finds and runs its commands, writes the CLAUDE.md sections, creates labels, configures the board workflow, and checks main-branch protection |
| `/factory:plan <issues> [--batch] [--design N \| --no-design]` | Plans each issue, creates its branch, commits and pushes the plan, links it from the issue |
| `/factory:design <issue> [--options N] [--choose X]` | Creates design options for UI work as a Design artifact, links them from the plan, and snapshots the one you pick onto the branch |
| `/factory:build <issue>` | Builds from the plan branch with review agents, opens the PR, and sees review findings through until it merges. Run it again to resume an interrupted build |
| `/factory:pr-audit <pr>` | Read-only review of any PR against the rulebook, posted as one COMMENT review; on factory PRs it also checks the plan and evidence |
| `/factory:status` | Lists factory issues by stage, and flags stalled builds, merged PRs whose issue is still open, and leftover labels |

`/factory <mode> <args>` (for example `/factory build 41`) also works and routes to the same commands.

Every command runs only when you type it at the start of a message; Claude can't start one on its own. That keeps anything that writes to GitHub or edits code behind a deliberate entry point.

When a command needs a decision from you in the session, it asks in a popup with suggested answers, its recommendation first. It never leaves a question in the transcript for you to find. Unattended runs put the question on the issue instead.

## Planning: with you or in batch

- **One issue (`/factory:plan 41`):** it drafts the plan, shows you the size, approach, scope fence and open questions, and waits. You answer, it revises, and you can approve on the spot, which labels the issue `factory:ready`.
- **Several issues, or `--batch`:** no stops. Open questions stay in each plan for you to answer later. Use this for an afternoon of planning or an unattended cloud run.

### Batch examples

Plan three issues in one run:

```bash
/factory:plan 41 42 43
```

Plan one issue without stopping to ask you anything:

```bash
/factory:plan 44 --batch
```

Give every plan that changes the UI three design options, or skip design:

```bash
/factory:plan 41 42 43 --design 3
```

```bash
/factory:plan 41 42 43 --no-design
```

How batch differs from planning one issue with you:

| | With you (one issue) | Batch (several issues, or `--batch`) |
|---|---|---|
| Plan writers | One | One per issue, in parallel, at most 5 at a time |
| Open questions | Asked in popups during the run | Left in each plan, for you to answer on the issue |
| Approval | You can approve in the session (`factory:ready`) | Every issue ends at `factory:planned` |
| Design | Asks whether to include it and how many options | Follows `--design N` or `--no-design`. With neither, the plan marks design "not decided" and adds an open question to run `/factory:design <n>` |
| Issues already building or in review | Skipped | Skipped, and named in the report |

Each issue still gets its own branch, plan file, push and `## Factory plan` comment. An issue too big to plan (XL) gets a split proposal and `factory:needs-human` instead. The run ends with a table of every issue, its size, its open questions and links to its plan and comment.

After a batch run:

1. Read each plan on GitHub. Answer its open questions as comments on the issue, or edit the plan file on the branch.
2. Run `/factory:design <n>` for any issue whose design is "not decided" or still waiting for a pick.
3. Add `factory:ready` to each issue you approve.
4. Build each one with `/factory:build <n>`. A build takes one issue, so run one session per issue to build in parallel.

Batch planning suits related stories, such as an epic's children, or a scheduled cloud run that plans overnight for you to review in the morning. When one story depends on another, its plan names that as a build gate. Build them in that order: a build stops and escalates if the code it depends on isn't on the base branch yet. `/factory:status` shows which issues are waiting on you.

To change a plan after it's pushed, edit the plan file on the branch. Answers and notes you leave as issue comments are read by `/factory:build` as clarifications; if one contradicts the plan, the build stops and asks rather than guessing.

## Design options

When a plan changes screens a user sees, `/factory:plan` asks whether to include design and how many options you want (1–4, default 3). In batch mode, pass `--design 3` or `--no-design`, or decide later with `/factory:design <issue>`.

1. The factory writes a design brief from the issue: the screens, their empty, loading, error and success states, real content, and N directions that differ in layout or flow, not just color.
2. It draws the options on one Design artifact in Claude, one labelled group of artboards per direction, and links it from the plan's `### Design` section and the issue. Artifacts start private, so share the canvas with your team.
3. You pick one, in the session or with `/factory:design <issue> --choose B`. The factory copies the chosen option onto the branch at `plans/<n>-<slug>-design/`, so the builder and a cloud build that can't open claude.ai still have it.
4. The builder builds to that snapshot, and the UI reviewer compares the result against it.

An issue stays `factory:planned` until a design is picked, and `/factory:build` stops and asks if the design is still open.

Set `Factory design system:` in CLAUDE.md to say what designs should look like: a claude.ai design system link, or the app's own components and styles to match. Optionally, run `/design-sync` once to load the repo's components into a design system. A session without the Design artifact type uses Claude Design tools if it has them; otherwise it prints the brief for you to make the design in Claude and paste the link back.

## What's in here

```text
.claude/
  commands/factory/
    setup.md  plan.md  design.md  build.md  pr-audit.md  status.md
.github/workflows/factory-board.yml  moves board cards when stage labels change
  skills/factory/SKILL.md          /factory <mode> router
  factory/
    conventions.md                 flow, branch and plan file, labels, asking a human, REST calls, worktrees, subagents, reviewers
    planning.md                    planning procedure + plan template
    audit-rulebook.md              starter review rules (pr-audit and code reviewer)
  agents/
    factory-spec-writer.md         fable (relaunched on opus if fable isn't available)
    factory-builder.md             opus
    factory-reviewer-security.md   opus
    factory-reviewer-code.md       sonnet
    factory-reviewer-ux.md         sonnet
    factory-reviewer-ui.md         sonnet
    factory-approver.md            opus
  hooks/factory-guard.sh           blocks merges, force pushes, pushes to main, branch deletion
  settings.json                    registers the guard hook
scripts/factory-install.sh         installs the factory into a repo, or updates one that has it
scripts/test-factory-install.sh    tests the installer against throwaway repos
scripts/factory-labels.sh          creates the stage labels
claude-md-snippet.md               sections to add to the repo's CLAUDE.md
```

Why it lives in the repo: cloud sessions clone the repo from GitHub and never see your laptop's `~/.claude`. Commands, skills, agents and hooks committed under `.claude/` load in every session automatically.

`model: fable`, `model: opus` and `model: sonnet` always mean the latest of each. Change one line to move an agent up or down.

Planning runs on Fable, the strongest model, because a plan is one cheap run that everything after it depends on. An agent has no fallback setting of its own, so the fallback lives in the commands: if the plan writer can't start on Fable (not on your plan, or rate-limited), `/factory:plan` launches it again on Opus and says so. The `/factory:plan` and `/factory:design` commands also ask for Fable in their own frontmatter. That holds only for the turn the command starts in, and is ignored where Fable isn't available, so for design work start the session itself on Fable. To cover an overloaded model in the middle of a run, add `"fallbackModel": ["opus"]` to your settings; note that it applies to every Claude Code session that reads those settings, not only factory commands.

If the repo has its own `.claude/rules/audit-rulebook.md`, the reviewers and `/factory:pr-audit` use it. Otherwise they fall back to the starter rulebook, which uses the same §1–§5 numbering.

## GitHub calls are REST-only

In cloud sessions, Anthropic's GitHub proxy rejects GraphQL, and `gh issue …`, `gh pr …` and `gh repo view` all use GraphQL. Every factory command uses `gh api` REST calls instead, which work the same locally and in the cloud. `gh` is pre-installed in cloud sessions and signs in through the proxy, so there's no token to manage. GitHub Projects are GraphQL-only, so board moves happen in a GitHub Action instead (next section).

## The kanban board

Each stage label maps to a column, and an issue's card moves when its label changes:

| Label | Default column |
|---|---|
| `factory:planned` | Planned |
| `factory:ready` | Ready |
| `factory:building` | In Progress |
| `factory:in-review` | In Review |
| `factory:needs-human` | Blocked |
| issue closed by the merged PR | Done (the board's built-in "Item closed" workflow) |

The commands don't move cards themselves. GitHub Projects can only be changed through GraphQL, and cloud sessions can't reach it. So `.github/workflows/factory-board.yml` runs on GitHub every time a factory label is added and moves the card, adding the issue to the board first if needed. Setup (below) points it at your board. It works the same whether the label came from a cloud session, your laptop, or you clicking in GitHub, so moving the label by hand moves the card too.

## 1. Add it to a repo (20 min)

1. Clone this repo next to yours and run the installer, pointing it at your repo's root:

   ```bash
   git clone https://github.com/bholdman/code-factory
   ```

   ```bash
   code-factory/scripts/factory-install.sh --check path/to/your-repo
   ```

   ```bash
   code-factory/scripts/factory-install.sh path/to/your-repo
   ```

   The `--check` run lists what would be added and changes nothing. The install copies the factory's commands, agents, reference files, skill and guard hook into `.claude/`. It adds `.claude/settings.json` and `.github/workflows/factory-board.yml` only if the repo doesn't have them yet; an existing `settings.json` is left as it is, and setup merges the hook in. It doesn't touch your README, CLAUDE.md or anything else, so it is safe in a repo that already has its own `.claude/` folder.

   Without a shell, copy the `.claude/` and `.github/` folders into the repo root by hand, merging with any that already exist.
2. Commit and push the factory files to the base branch (or open a PR for them). Cloud sessions clone from GitHub, so files you haven't pushed don't exist for them.
3. Run **`/factory:setup`**, locally or in a cloud session. It:
   - reads existing Claude Code commands and skills, CI, and project files to find the install, test, lint and run commands, and the PR base branch (for example `staging`)
   - runs each command and only records the ones it saw succeed, plus how long the suite takes and any tests that already fail
   - matches the naming of plans already in `plans/`
   - creates the stage labels
   - fills in the board workflow's board number and column names (run it locally and it reads the columns from your board; in a cloud session it asks you for them)
   - checks the hook, main-branch protection, and the board token
   - shows you everything, then opens a `factory/setup` PR with the changes
4. Merge that PR, then finish what it lists as needing a human:
   - **Board token:** create a token that can edit the board. A fine-grained token owned by the org works: organization permission **Projects: Read and write**, and repository access to this repo with **Issues: Read**. Add it as a repo secret named `FACTORY_PROJECT_TOKEN`.
   - **Done column:** in the board's settings → Workflows, turn on **Item closed** (set to Done) so merged work lands in Done.
   - **Main-branch ruleset:** section 3.
5. Test the board: add `factory:ready` to any issue by hand and watch the card move. If a column name doesn't match, the Action fails with a message naming it.

Run `/factory:setup --check` any time to see what's missing without changing anything. `scripts/factory-labels.sh` still works if you want to create the labels by hand.

## Updating a repo that already has the factory

The factory changes as builds teach it things. To bring a repo up to the current version, pull this repo and run the same installer:

```bash
git -C code-factory pull
```

```bash
code-factory/scripts/factory-install.sh --check path/to/your-repo
```

```bash
code-factory/scripts/factory-install.sh path/to/your-repo
```

`--check` lists each file that would change and exits 1 if the repo is behind, so it also works as a "are we current?" test. After the real run, read `git diff` in your repo, commit on a branch and merge it to the base branch. Cloud sessions load the commands from GitHub, so an update only takes effect once it's merged.

What an update does to each kind of file:

| Files | On update |
|---|---|
| **Factory files:** `.claude/commands/factory/`, `.claude/agents/factory-*.md`, `.claude/factory/*.md`, `.claude/skills/factory/`, `.claude/hooks/factory-guard.sh` | Replaced with this repo's version |
| **Repo files:** `.claude/settings.json`, `.github/workflows/factory-board.yml` | Kept. The installer says when yours differs from this repo's, so you can bring a change across by hand and keep your board number and column names |
| `CLAUDE.md`, `.claude/rules/audit-rulebook.md`, `plans/` and everything else | Never touched |

- **Edits you made to factory files are replaced.** They stay in your git history, and `git diff` shows exactly what changed before you commit. Keep team rules in CLAUDE.md or `.claude/rules/audit-rulebook.md`; the factory reads both and the installer leaves them alone. If you improved a factory file, open a PR here so every repo gets it.
- **Uncommitted edits are protected.** A factory file with uncommitted changes is reported as `BLOCKED` and left alone. Commit or stash it and run again, or pass `--force`.
- **Files the factory no longer ships** are reported as `stale`. Pass `--prune` to delete them.
- **The version is recorded** in `.claude/factory/VERSION` (this repo's commit and date), and the installer prints it next to the version it is about to install.
- **Then run `/factory:setup --check`.** An update never edits CLAUDE.md, so a new setting the update expects, such as `Factory worktree prep:`, shows up there as missing. Run `/factory:setup` to fill it in.

## 2. Create a cloud environment for the repo (10 min)

At claude.ai/code, open the environment selector under the message box and add an environment named after the repo:

- **Network access:** Trusted (the default)
- **Setup script:** only toolchains the VM doesn't already have, which is often nothing. Cloud sessions already include `gh`, git, Node, Ruby, Python, PostgreSQL, Redis and Docker. Keep any script under about 5 minutes so it gets cached.
- **Project dependencies** (`bundle install`, `npm ci`): install them with a SessionStart hook committed to the repo, so they run in cloud and local sessions alike. Anthropic's cloud environments docs have a ready-made example that runs only in the cloud (it checks `CLAUDE_CODE_REMOTE`).
- **GitHub token:** none.

Check it once: start a cloud session on that environment and ask Claude to run `gh api user -q .login`.

## 3. Protect main (5 min)

The cloud GitHub proxy doesn't limit which branches a session can push to, so this ruleset is what actually protects main. In the repo's Settings → Rules → Rulesets, create a branch ruleset on the default branch:

- Require a pull request before merging
- Block force pushes
- Restrict deletions

About approvals: cloud sessions act as your GitHub account, so factory PRs are authored by you, and GitHub won't let you approve your own PR. Pick one:

- **Required approvals = 0.** Your click on Merge is the gate, and the guard hook keeps agents from merging.
- **Required approvals = 1.** A teammate approves. List them after `Factory reviewers:` in CLAUDE.md and the factory requests their review.

## 4. Run it

**Plan:**

- Batch: `/factory:plan 41 42 43`, then read the plans on GitHub (each issue links its plan file), edit any that need it, and add `factory:ready` to the ones you approve.
- One at a time: `/factory:plan 41`, answer its questions, and approve in the session.

**Build** (one cloud session per issue; that's your parallelism):

- Desktop app → Code → new session → **Cloud** → the repo's environment → permission mode **Auto** → `/factory:build 41`. Repeat for 42, 43, and so on.
- From a terminal in the repo: `for n in 41 42 43; do claude --cloud "/factory:build $n"; done`
- From your phone: Claude app → Code tab → new session, same command.

Auto mode keeps a build from stalling on permission prompts while you're away. The guard hook still runs.

**Watch and steer:** every cloud session shows up in the Desktop app, at claude.ai/code, and in the Code tab on your phone.

**Review and merge:** the PR comes from the issue's branch, links the plan, and lists evidence for each acceptance criterion. Run `/factory:pr-audit <pr>` if you want an independent pass first. You merge, and `Closes #N` closes the issue.

**Status any time:** `/factory:status`

## How an issue moves

| Label | Meaning | Who sets it |
|---|---|---|
| `factory:planned` | Plan pushed; read it | `/factory:plan` |
| `factory:ready` | Approved to build | You, or `/factory:plan` when you approve in session |
| `factory:building` | Build running | `/factory:build` |
| `factory:in-review` | PR open; review it | `/factory:build` |
| `factory:needs-human` | Blocked on one question | Any command |

On `factory:needs-human`, read the `## Factory decision` comment, answer in the issue or edit the plan file, re-add `factory:ready`, and run `/factory:build` again. It picks up on the same branch. In a session you're watching, a blocked build asks you in a popup first and carries on with your answer.

A build that was interrupted keeps `factory:building`; run `/factory:build` on it again to resume. When the PR merges, the build removes `factory:in-review` if its session is still watching, and `/factory:status` lists any label left behind.

## Tips

- Start with 3 builds at once. Cloud sessions share your Claude plan's usage limits, and each build runs a builder, up to four reviewers and an approver per round, mostly on Opus. Planning runs on Fable, which draws more from those limits per run.
- Commands must start the message. "Please /factory:build 41" won't run it.
- Both commands work in a temporary git worktree, so your own checkout is never switched or touched. A new worktree holds only tracked files: if tests need built assets or generated files, set `Factory worktree prep:` in CLAUDE.md (`/factory:setup` finds it).
- Changes sized M or larger, and ones that touch money, webhooks, jobs, migrations or permissions, get their code review on the session's strongest model. Small changes to an existing screen get one frontend reviewer instead of two.
- If the repo has a skill or command with a browser acceptance-testing procedure, the UI reviewer follows it. Commit it to the repo so cloud sessions see it too.

## Credits

Inspired by the software factory in zazencodes' [Season 3 repo](https://github.com/zazencodes/zazencodes-season-3/tree/main/src/software-factory-claude-code): one orchestrator, specialist subagents, and a human gate before merge.
