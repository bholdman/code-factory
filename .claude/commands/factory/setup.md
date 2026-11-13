---
description: Factory — prepare this repo for the factory. Finds and verifies the repo's install, test, lint and run commands, writes the CLAUDE.md sections, creates the stage labels, and checks the board, main-branch protection and hook.
argument-hint: "[--check]"
disable-model-invocation: true
---

# /factory:setup

Arguments: `$ARGUMENTS` (`--check` reports what's missing and changes nothing)

Read `.claude/factory/conventions.md` first and set `REPO` and `DEFAULT` from it.

Every builder and reviewer runs the commands this writes into CLAUDE.md, so a wrong command is worse than a missing one: agents would "pass" against it. Only write a command you have run and seen succeed. Safe to re-run; it updates what changed and leaves the rest.

## 0. Check the factory files are here

Confirm these exist: `.claude/commands/factory/{plan,design,build,status,pr-audit,retro}.md`, `.claude/factory/{conventions,planning,audit-rulebook}.md`, the eight `.claude/agents/factory-*.md` files, `.claude/hooks/factory-guard.sh`, and `.github/workflows/factory-board.yml`. If any are missing, stop and say which; they come from the factory package and aren't something to generate.

## 1. Gather what the repo already says

Read, in this order, and note every command and setting you find:

1. **Existing Claude Code commands and skills.** Look through `.claude/commands/` and `.claude/skills/` for configuration the team already wrote down, such as a test command, a pre-commit or hooks command, the PR base branch, a branch naming convention, file globs, or a project board. These are the team's own values and are the strongest hints.
2. **CI.** `.github/workflows/*.yml`: the install, setup, test and lint steps CI actually runs, and the services it starts (Postgres, Redis).
3. **Project files.** `package.json` scripts, `Gemfile` and `bin/` (for example `bin/setup`, `bin/rails`, `bin/dev`), `Makefile`, `Procfile*`, `docker-compose*.yml`, `pyproject.toml`, `.tool-versions`, `.ruby-version`, `.nvmrc`.
4. **Docs.** `README*`, `CONTRIBUTING*`, and the existing `CLAUDE.md`, including any project rules or orientation block.
5. **Plans.** List the root `plans/` folder (or wherever plans live). If existing files follow a naming pattern, such as `123-short-title.md` or `2026-10-01-title.md`, record it for `Factory plan file:`.

## 2. Verify each command

Run each candidate and record what happened. Stop a command that hangs.

1. **Services.** Start what the tests need. In a cloud session (`CLAUDE_CODE_REMOTE=true`): `service postgresql start`, `service redis-server start`, or `docker compose up -d <service>`. Locally, check whether they're already running before starting anything.
2. **Install.** Run it. Then any database setup (for example `bin/rails db:prepare`, migrations, seeds); this becomes "Seed or test data".
3. **Unit tests.** First run a single fast test file to prove the command's shape works. Then run the full suite once. If it takes more than about 10 minutes, run it in the background and check back. Record how long the full suite took, since builders use that to decide when to run it. If tests fail before any change, record which ones; that's the baseline, not something to fix here.
4. **Lint and type check.** Run them. Record pre-existing failures the same way.
5. **Pre-commit checks.** If the repo uses them (overcommit, pre-commit, husky, lefthook, or a `HOOKS_CMD`), run them.
6. **Start the app.** Start it in the background, poll the URL until it answers (up to about 90 seconds), note the URL and port, then stop it. If it needs a login for browser checks, look for a seeded test account; never record a real one. Log in with it once before recording it. Docs and seed files drift apart, and a login that doesn't work costs every UI review a detour.
7. **A fresh worktree.** Builds and reviews run in a new git worktree, which holds only tracked files. Create one (`git worktree add /tmp/factory-setup/wt origin/$BASE_BRANCH`), run the single fast test file and the pre-commit checks there, then remove it. Whatever it took to make them pass that git doesn't track (compiling assets, generating files, signing hook config) becomes `Factory worktree prep:`. If nothing was needed, leave that setting out.

A command you can't get working stays in the section with a short note on what failed, so a human can finish it.

## 3. Draft the CLAUDE.md sections

Draft both sections in the format of `claude-md-snippet.md`, filled in:

```markdown
## Commands the factory runs

- Install: `<cmd>`
- Seed or test data: `<cmd>`
- Unit tests: `<cmd>` (full suite ~<n> min; single file: `<cmd> <path>`)
- Lint and type check: `<cmd>`
- Pre-commit checks: `<cmd>`
- Start the app for browser checks: `<cmd>` (URL: <url>)
- Test login for browser checks: <where the seeded test account comes from>
- Services: <what must be running, how to start it in a cloud session, and how to restart it after the container has idled>
- Known failures before any change: <tests or lint rules that already fail, or "None">

## Factory settings

- Factory base branch: <the PR base branch the team already uses, else the repo's default branch>
- Factory branch: <the team's branch convention if one exists, else factory/{number}-{slug}>
- Factory plan dir: plans
- Factory plan file: <detected pattern, else {number}-{slug}.md>
- Factory worktree prep: <the command from step 2.7; leave out if a fresh worktree needed nothing>
- Factory reviewers: <ask with the popup; leave out if none>
- Factory design system: <ask with the popup: the app's own components and styles, naming which ones designs must match, or a claude.ai design system link>
- MAX_INLINE: <the team's existing value, else 15>
- APP_GLOBS / TEST_GLOBS / MIGRATION_GLOBS / FRONTEND_GLOBS: <the team's existing globs, else inferred from the layout>
```

If CLAUDE.md already has these sections, update them in place and keep anything a human wrote there. Leave the rest of CLAUDE.md alone.

## 4. Check the rest of the setup

Report each item as done, fixed, or needs a human. Fix only what's marked as yours to fix.

| Check | How | If it's missing |
|---|---|---|
| Guard hook registered | `.claude/settings.json` has the `PreToolUse` Bash hook for `factory-guard.sh` | Merge it into the existing settings (yours to fix) |
| Stage labels | `gh api repos/$REPO/labels --paginate` | Create each missing one (yours to fix, below) |
| Base branch protected | `gh api repos/$REPO/rulesets` and `gh api repos/$REPO/branches/$BASE_BRANCH/protection` (a 404 means none) | Needs a human: a ruleset that requires a PR and blocks force pushes and deletion. Give them the link `https://github.com/$REPO/settings/rules` |
| Board workflow configured | `.github/workflows/factory-board.yml` still has `PROJECT_NUMBER: "1"` and the default column names | Fill it in (below) |
| Board token | `gh api repos/$REPO/actions/secrets -q '.secrets[].name'` includes `FACTORY_PROJECT_TOKEN` (a 403 means you can't see secrets; say so) | Needs a human: create the token and the secret, as the factory's README describes. Never ask for or handle the token yourself |
| Design tool | the Artifact tool offers a Design type (`quickstart` with intent `design`) | Note it. Without it, `/factory:design` prints the brief for a human to make the design in Claude and paste the link back. Optional: run `/design-sync` once so designs start from the repo's own components |
| Plans folder | the plan dir exists | Note it; `/factory:plan` creates files there |

**Creating labels** (REST, so it works in cloud sessions):

```bash
mk() { gh api repos/$REPO/labels -f name="$1" -f color="$2" -f description="$3" >/dev/null 2>&1 \
  || gh api -X PATCH "repos/$REPO/labels/${1/:/%3A}" -f color="$2" -f description="$3" >/dev/null; }
mk factory:planned     FBCA04 "Plan posted; waiting for human approval"
mk factory:ready       0E8A16 "Plan approved; OK to build"
mk factory:building    1D76DB "Build session running"
mk factory:in-review   5319E7 "PR open; waiting for human review"
mk factory:needs-human D93F0B "Agent escalated; needs a human decision"
```

**Filling in the board workflow:**

- Owner and number: from existing configuration if it names a board (such as `your-org/12`); otherwise ask for the board's URL with the popup (the person types it under "Other"; offer "No board" as a choice).
- Column names: they must match the board's Status options exactly.
  - Locally, read them: `gh project field-list <number> --owner <owner> --format json` and use the options of the Status field (or whichever field the board's columns come from).
  - In a cloud session that call fails, because the GitHub proxy blocks GraphQL. Ask for the board's column names with the popup (the person types them under "Other").
- Map each stage label to the closest column and show the mapping. Leave a `COL_*` blank where no column fits.

## 5. Confirm, then save

Show the human, in one message:

- the two CLAUDE.md sections as you'd write them
- the board mapping
- the checklist from step 4

Ask with the popup: "Save these and open a PR?" (Save and open a PR (Recommended) / Change something first / Don't save). Every question in this command goes through the popup, as conventions.md ("Asking a human") describes; ask the ones you still have open in one call. On yes:

1. Create the branch `factory/setup` from `origin/$BASE_BRANCH` in a worktree (conventions.md).
2. Write the CLAUDE.md sections, any `.claude/settings.json` hook merge, and the board workflow values. Labels are already created on GitHub and need no commit.
3. Commit (`chore: set up the factory`), push, and open a PR into `$BASE_BRANCH` whose body lists what was verified and every item that still needs a human.

Cloud sessions only see what's on the base branch, so the factory is ready once this PR merges.

With `--check`, skip steps 3 and 5: report the checklist and which commands are missing or unverified, and change nothing.

## 6. Report

End with the checklist: what's set up, what changed, and what still needs a human (the main-branch ruleset, the board token, the cloud environment's setup script if a tool was missing). Then: "After this merges, try `/factory:plan <issue>` on a small issue."
