---
name: factory
description: Entry point for the software factory. Routes `/factory <mode> <args>` to the matching /factory:<mode> command — setup, plan, design, build, status, pr-audit or retro.
argument-hint: setup|plan|design|build|status|pr-audit|retro <args>
disable-model-invocation: true
---

# /factory

Arguments: `$ARGUMENTS`

The first word is the mode and the rest are its arguments. Read `.claude/commands/factory/<mode>.md` and follow it exactly as if the user had run `/factory:<mode> <rest>`.

| Mode | Command | What it does |
|---|---|---|
| `setup` | `/factory:setup` | Prepares a repo: finds and verifies its commands, writes CLAUDE.md settings, creates labels, checks the board |
| `plan` | `/factory:plan <issues>` | Plans each issue, creates its branch, commits and pushes the plan |
| `design` | `/factory:design <issue> [--options N] [--choose X]` | Creates design options as a Design artifact, links them from the plan, snapshots the pick |
| `build` | `/factory:build <issue>` | Checks out the plan's branch, builds with review agents, opens a PR |
| `status` | `/factory:status` | Lists factory issues by stage |
| `pr-audit` | `/factory:pr-audit <pr>` | Read-only review of any PR, posted as one comment review |
| `retro` | `/factory:retro [--since DATE \| --last N] [--dry-run]` | Finds what recent builds caught late and proposes lessons for CLAUDE.md as a PR |

If there's no mode, or the mode isn't in the table, show the table and stop.

Every mode follows `.claude/factory/conventions.md`, including **Keep it simple**: take the simplest approach that meets the request without giving up security or required behaviour, and tell the developer before a decision significantly increases complexity.
