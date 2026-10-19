# Claude Code Software Factory

A set of Claude Code commands, subagents and hooks that turn GitHub issues into reviewed pull requests. You plan issues, approve the plans, and fire off builds in parallel cloud sessions you can watch from your phone. Specialist agents review every change for security, UX, UI and code quality, and a human always merges.

Drop this into a repo, commit it, and the `/factory:*` commands work in every Claude Code session on that repo: local, cloud, Desktop app, or phone.

## Requirements

- Claude Code with access to cloud sessions (Claude Code on the web), and the Claude GitHub app installed on the repo
- A GitHub repo with issues
- Optional: a GitHub Projects board, for the kanban automation
- Optional: the `gh` CLI on your laptop, for running commands locally

## How it works

1. **`/factory:plan 41`** plans the issue, creates its branch (`factory/41-csv-invoice-export`), commits the plan to the root `plans/` folder (`plans/41-csv-invoice-export.md`), pushes, and links the plan from the issue.
2. **You approve** by adding `factory:ready`. With one issue you can also answer its questions and approve right in the session.
3. **`/factory:build 41`** checks out that branch, reads the plan file, builds test-first, runs the reviewers, and opens the PR from the same branch.
4. **You review and merge.** The plan file merges with the code, so the plan stays next to the change it explains.

| Command | What it does |
|---|---|
| `/factory:setup [--check]` | Prepares the repo: finds and runs its commands, writes the CLAUDE.md sections, creates labels, configures the board workflow, and checks main-branch protection |
| `/factory:plan <issues> [--batch] [--design N \| --no-design]` | Plans each issue, creates its branch, commits and pushes the plan, links it from the issue |
| `/factory:design <issue> [--options N] [--choose X]` | Creates design options in Claude Design for UI work, links them from the plan, and snapshots the one you pick onto the branch |
| `/factory:build <issue>` | Builds from the plan branch with review agents, opens the PR |
| `/factory:pr-audit <pr>` | Read-only review of any PR against the rulebook, posted as one COMMENT review; on factory PRs it also checks the plan and evidence |
| `/factory:status` | Lists factory issues by stage |

`/factory <mode> <args>` (for example `/factory build 41`) also works and routes to the same commands.

Every command runs only when you type it at the start of a message; Claude can't start one on its own. That keeps anything that writes to GitHub or edits code behind a deliberate entry point.

## Planning: with you or in batch

- **One issue (`/factory:plan 41`):** it drafts the plan, shows you the size, approach, scope fence and open questions, and waits. You answer, it revises, and you can approve on the spot, which labels the issue `factory:ready`.
- **Several issues, or `--batch`:** no stops. Open questions stay in each plan for you to answer later. Use this for an afternoon of planning or an unattended cloud run.

To change a plan after it's pushed, edit the plan file on the branch. Answers and notes you leave as issue comments are read by `/factory:build` as clarifications; if one contradicts the plan, the build stops and asks rather than guessing.

## Design with Claude Design

When a plan changes screens a user sees, `/factory:plan` asks whether to include design and how many options you want (1–4, default 3). In batch mode, pass `--design 3` or `--no-design`, or decide later with `/factory:design <issue>`.

1. The factory writes a design brief from the issue: the screens, their empty, loading, error and success states, real content, and N directions that differ in layout or flow, not just color.
2. It creates a Claude Design project for the issue with one option per direction, and links the project and each option from the plan's `### Design` section and the issue.
3. You pick one, in the session or with `/factory:design <issue> --choose B`. The factory copies the chosen option onto the branch at `plans/<n>-<slug>-design/`, so a cloud build that can't open Claude Design still has it.
4. The builder builds to that snapshot, and the UI reviewer compares the result against it.

An issue stays `factory:planned` until a design is picked, and `/factory:build` stops and asks if the design is still open.

Creating designs from a session needs the Claude Design MCP server, connected once on your machine:

```bash
claude mcp add --scope user --transport http claude-design https://api.anthropic.com/v1/design/mcp
```

Then run `/design-sync` once per repo, so designs start from the repo's real components. Without the server (common in cloud sessions), the factory prints the brief and a `/design …` command to run in Claude Code Desktop or the terminal, and you paste the project link back.

## What's in here

```text
.claude/
  commands/factory/
    setup.md  plan.md  design.md  build.md  pr-audit.md  status.md
.github/workflows/factory-board.yml  moves board cards when stage labels change
  skills/factory/SKILL.md          /factory <mode> router
  factory/
    conventions.md                 flow, branch and plan file, labels, REST calls, worktrees, reviewers
    planning.md                    planning procedure + plan template
    audit-rulebook.md              starter review rules (pr-audit and code reviewer)
  agents/
    factory-spec-writer.md         opus
    factory-builder.md             opus
    factory-reviewer-security.md   opus
    factory-reviewer-code.md       sonnet
    factory-reviewer-ux.md         sonnet
    factory-reviewer-ui.md         sonnet
    factory-approver.md            opus
  hooks/factory-guard.sh           blocks merges, force pushes, pushes to main, branch deletion
  settings.json                    registers the guard hook
scripts/factory-labels.sh          creates the stage labels
claude-md-snippet.md               sections to add to the repo's CLAUDE.md
```

Why it lives in the repo: cloud sessions clone the repo from GitHub and never see your laptop's `~/.claude`. Commands, skills, agents and hooks committed under `.claude/` load in every session automatically.

`model: opus` and `model: sonnet` always mean the latest of each. Change one line to move an agent up or down.

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

1. Copy the `.claude/` and `.github/` folders into the repo root, merging with any that already exist. Don't copy this README over the repo's own. If the repo already has `.claude/settings.json`, keep it; setup merges the hook in.
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

On `factory:needs-human`, read the `## Factory decision` comment, answer in the issue or edit the plan file, re-add `factory:ready`, and run `/factory:build` again. It picks up on the same branch.

## Tips

- Start with 3 builds at once. Cloud sessions share your Claude plan's usage limits, and each build runs a builder, up to four reviewers and an approver per round, mostly on Opus.
- Commands must start the message. "Please /factory:build 41" won't run it.
- Both commands work in a temporary git worktree, so your own checkout is never switched or touched.
- If the repo has a skill or command with a browser acceptance-testing procedure, the UI reviewer follows it. Commit it to the repo so cloud sessions see it too.

## Credits

Inspired by the software factory in zazencodes' [Season 3 repo](https://github.com/zazencodes/zazencodes-season-3/tree/main/src/software-factory-claude-code): one orchestrator, specialist subagents, and a human gate before merge.
