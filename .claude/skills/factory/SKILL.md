---
name: factory
description: Entry point for the software factory. Routes `/factory <mode> <args>` to the matching /factory:<mode> command — setup, plan, build, status, or pr-audit.
argument-hint: setup|plan|build|status|pr-audit <args>
disable-model-invocation: true
---

# /factory

Arguments: `$ARGUMENTS`

The first word is the mode and the rest are its arguments. Read `.claude/commands/factory/<mode>.md` and follow it exactly as if the user had run `/factory:<mode> <rest>`.

| Mode | Command | What it does |
|---|---|---|
| `setup` | `/factory:setup` | Prepares a repo: finds and verifies its commands, writes CLAUDE.md settings, creates labels, checks the board |
| `plan` | `/factory:plan <issues>` | Plans each issue, creates its branch, commits and pushes the plan |
| `build` | `/factory:build <issue>` | Checks out the plan's branch, builds with review agents, opens a PR |
| `status` | `/factory:status` | Lists factory issues by stage |
| `pr-audit` | `/factory:pr-audit <pr>` | Read-only review of any PR, posted as one comment review |

If there's no mode, or the mode isn't in the table, show the table and stop.
