---
description: Factory — create design options for an issue's UI work as a Design artifact, link them from the plan, and record the option the human picks
argument-hint: <issue> [--options N] [--choose <option>]
disable-model-invocation: true
---

# /factory:design

Arguments: `$ARGUMENTS`

Read `.claude/factory/conventions.md` first. `/factory:plan` runs this command's steps when a plan includes design work; you can also run it on its own, for example after a batch plan, or to add options later.

A builder working from a picked design builds what the human actually wants. A builder working from a text description builds its own guess. So for UI work, the plan carries a link to the design options, and once the human picks one, a snapshot of it on the branch.

## 1. Load the issue and plan

Read the issue, its latest `## Factory plan` comment, the branch, and the plan file (conventions.md). If there's no plan yet, stop and suggest `/factory:plan <n>`.

From the plan, list the screens and states the change touches: each new or changed screen, plus its empty, loading, error and success states where they apply. If nothing user-facing changes, say so and stop.

## 2. Ask (unless the arguments already answer it)

Ask with the popup (conventions.md, "Asking a human"), as two questions in one call:

1. "This issue changes <screens>. Include design?" (Yes / No)
2. "How many design options?" (3 (Recommended) / 1 / 2 / 4)

With `--options N`, skip both questions. On "no", record `Status: skipped` in the plan (step 5) and stop.

## 3. Write the design brief

Write the brief to `/tmp/factory-<n>/design-brief.md`:

- what the user is trying to do, from the issue and its acceptance criteria
- each screen and state from step 1
- real content to show: field names, sample data, and copy from the issue, following CLAUDE.md's rules for user-facing wording
- constraints: `Factory design system:` from CLAUDE.md, the existing screens this must sit next to, and target widths (desktop and mobile)
- **N distinct directions.** Name each one by the idea it tries, such as "compact table", "card list", or "guided wizard". They should differ in layout or flow, not just in color, so the human has a real choice.

## 4. Create the designs

**With the Artifact tool's Design type** (check with Artifact `quickstart`, intent `design`):

1. **Match the app.** If `Factory design system:` is a claude.ai design system link, run the quickstart with `design_systems: false` and read that design system with its own call. If it names the app's own components and styles instead, don't attach a design system: read those components, a neighboring screen, and the style config (for example the Tailwind theme), and reproduce their colors, type, spacing and components on the canvas so every option looks like this app. If the setting is missing, ask with the popup which to use (the app's own components (Recommended) / a claude.ai design system link); with nobody to answer, match the app's own components.
2. **Create the canvas.** Publish from the Design type's `type_url` with the title `#<n> <issue title>`, no files, and `auto_open: "after_first_write"`, then follow the instructions the create result carries. If the plan already links a design for this issue, update that artifact by its URL instead of creating another.
3. **Draw the options.** One canvas, with each option as its own labelled group of artboards (`A — compact table`, `B — card list`, …). Every option shows every screen and state from step 1, at desktop and mobile widths.
4. **Share.** Artifacts start private. Tell the human to share the canvas with the team from claude.ai, or reviewers on the issue can't open the link.

**Without the Design type, if Claude Design tools are available in this session:** use them the same way: one project for the issue, one option per direction, and a share link for the project and, if the tools provide them, for each option.

**With neither:**

1. Show the human the brief and ask them to make the design in Claude (a Design artifact on claude.ai, one labelled option per direction) and paste the link back.
2. With nobody in the session to answer, record `Status: waiting for designs` with the brief and stop at step 5.

## 5. Link the designs from the plan

Add or update the `### Design` section in the plan file, right after `### Steps`:

```markdown
### Design
**Needs design:** yes — <screens and states>
**Status:** waiting for a pick | chosen: <option> | skipped | waiting for designs
**Design:** [<canvas title>](<link>)
| Option | Direction | Where |
|---|---|---|
| A | compact table | artboards `A — …` (or the option's own link) |
| B | card list | artboards `B — …` |
**Chosen:** <option, once the human picks> · **Snapshot:** `plans/<n>-<slug>-design/` (once chosen)
```

Commit the plan file on the issue's branch (`docs(#<n>): add design options`) and push. Then post a short comment on the issue with the design link and one line per option, ending with: "Pick one with `/factory:design <n> --choose <option>`, or reply here with your pick."

The issue stays `factory:planned` until a design is chosen. Don't add `factory:ready` while the design status is waiting.

## 6. Record the pick (`--choose <option>`, or the human answers in the session)

With a person in the session and no `--choose`, ask with the popup which option to build: one choice per option, named by its direction. The popup takes at most four choices: with three options or fewer add "Pick later" as a choice, and with four leave it out, since the person can still defer under "Other".

1. Set `Status: chosen: <option>` and `Chosen: <option>` in the plan file.
2. **Snapshot the chosen option onto the branch.** The builder and reviewers can't open claude.ai, and the build may run in a cloud session, so they need a copy.
   - From a Design artifact: list its published files (Artifact `list` with `scope: "files"` and the canvas URL), fetch them with Artifact `read` and `paths`, and copy them into `plans/<n>-<slug>-design/`. If a browser tool is available, also save a PNG of each screen of the chosen option at desktop and mobile widths.
   - From Claude Design tools: export the chosen option as HTML (and a PNG per screen if the tools provide one) into the same folder.
   - Add a `README.md` there with the design link, the chosen option and which artboards make it up, and any notes the human gave.
   - If you can't fetch or export here, ask the human to export the option into that folder, and leave the status as `chosen: <option> (snapshot missing)`.
3. Commit (`docs(#<n>): design option <option> chosen`) and push.
4. If the plan has no open questions left and the human has approved it, move the issue to `factory:ready`. Otherwise leave it at `factory:planned`.

## 7. Report

The design link, the options, what was chosen (if anything), and what's next: pick an option, or build with `/factory:build <n>`.
