---
description: Factory — create design options in Claude Design for an issue's UI work, link them from the plan, and record the option the human picks
argument-hint: <issue> [--options N] [--choose <option>]
disable-model-invocation: true
---

# /factory:design

Arguments: `$ARGUMENTS`

Read `.claude/factory/conventions.md` first. `/factory:plan` runs this command's steps when a plan includes design work; you can also run it on its own, for example after a batch plan, or to add options later.

A builder working from a picked design builds what the human actually wants. A builder working from a text description builds its own guess. So for UI work, the plan carries links to the design options, and once the human picks one, a snapshot of it on the branch.

## 1. Load the issue and plan

Read the issue, its latest `## Factory plan` comment, the branch, and the plan file (conventions.md). If there's no plan yet, stop and suggest `/factory:plan <n>`.

From the plan, list the screens and states the change touches: each new or changed screen, plus its empty, loading, error and success states where they apply. If nothing user-facing changes, say so and stop.

## 2. Ask (unless the arguments already answer it)

Ask in one message:

1. "This issue changes <screens>. Include design?" (yes / no)
2. "How many design options? (1–4, default 3)"

With `--options N`, skip both questions. On "no", record `Design: skipped` in the plan (step 5) and stop.

## 3. Write the design brief

Write the brief to `/tmp/factory-<n>/design-brief.md`:

- what the user is trying to do, from the issue and its acceptance criteria
- each screen and state from step 1
- real content to show: field names, sample data, and copy from the issue
- constraints: the app's design system, existing screens this must sit next to, and target widths (desktop and mobile)
- **N distinct directions.** Name each one by the idea it tries, such as "compact table", "card list", or "guided wizard". They should differ in layout or flow, not just in color, so the human has a real choice.

## 4. Create the designs in Claude Design

**If the Claude Design MCP tools are available in this session** (the `claude-design` server):

1. Create one Claude Design project for the issue, named `#<n> <issue title>`. It inherits the organization's design system; if the design system was never synced, say so and suggest running `/design-sync` once.
2. Create the N options from the brief, one artboard or page per direction, each showing every screen and state from step 1.
3. Get a share link for the project and, if the tools provide them, a link for each option.

**If the tools aren't available** (common in cloud sessions):

1. Show the human the brief and this command to run in Claude Code Desktop or the terminal: `/design <the brief, condensed to a paragraph>`. To let future sessions do this automatically, they can connect the server once: `claude mcp add --scope user --transport http claude-design https://api.anthropic.com/v1/design/mcp`
2. Ask them to paste the project link back. With nobody in the session to answer, record `Design: waiting for designs` with the brief and stop at step 5.

## 5. Link the designs from the plan

Add or update a `### Design` section in the plan file, right after `### Steps`:

```markdown
### Design
**Status:** waiting for a pick | chosen: <option> | skipped | waiting for designs
**Claude Design project:** <link>
| Option | Direction | Link |
|---|---|---|
| A | compact table | <link> |
| B | card list | <link> |
**Chosen:** <option, once the human picks> · **Snapshot:** `plans/<n>-<slug>-design/` (once chosen)
```

Commit the plan file on the issue's branch (`docs(#<n>): add design options`) and push. Then post a short comment on the issue listing the options with their links, ending with: "Pick one with `/factory:design <n> --choose <option>`, or reply here with your pick."

The issue stays `factory:planned` until a design is chosen. Don't add `factory:ready` while the design status is waiting.

## 6. Record the pick (`--choose <option>`, or the human answers in the session)

1. Set `Status: chosen: <option>` and `Chosen: <option>` in the plan file.
2. **Snapshot the chosen option onto the branch.** The build may run in a cloud session that can't open Claude Design, so it needs a copy. Using the Claude Design tools, export the chosen option as HTML (and a PNG per screen if the tools provide one) into `plans/<n>-<slug>-design/`. Add a `README.md` there with the project link, the option name, and any notes the human gave. If exporting isn't possible here, ask the human to use Claude Design's export or handoff and drop the files in that folder, and leave the status as `chosen: <option> (snapshot missing)`.
3. Commit (`docs(#<n>): design option <option> chosen`) and push.
4. If the plan has no open questions left and the human has approved it, move the issue to `factory:ready`. Otherwise leave it at `factory:planned`.

## 7. Report

The project link, the options, what was chosen (if anything), and what's next: pick an option, or build with `/factory:build <n>`.
