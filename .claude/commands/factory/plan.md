---
description: Factory — plan GitHub issues, create each issue's branch, commit the plan to it and push, then link it from the issue for approval
argument-hint: <issue> [issue...] [--batch] [--design N | --no-design]
disable-model-invocation: true
model: fable
---

# /factory:plan

Arguments: `$ARGUMENTS` (none → ask with the popup, offering the most recently updated open issues that have no factory label)

Read `.claude/factory/conventions.md` first. It defines the branch and plan-file rules, labels, comment headings, REST-only GitHub calls and hard limits this command relies on.

Planning is cheap compared to building, and a human reads every plan, so aim for clear and specific over long. Don't write code here. This command commits only the plan file, and the design snapshot when a design is picked.

## Mode

- **With you (default for one issue):** one issue number and no `--batch`. You answer the plan's open questions in the session and can approve it on the spot.
- **Batch:** several issues, or `--batch`. No stops. Open questions stay in each plan for the human to answer on the issue. Use this for unattended cloud runs.

Design flags: `--design N` includes design with N options for every issue whose plan changes the UI, and `--no-design` skips design. Without either, you ask in with-you mode, and in batch mode the plan notes that design hasn't been decided.

## 1. Fetch

For each issue, read it and its comments (REST calls in conventions.md). Skip any issue labeled `factory:building` or `factory:in-review`, and say so. If an issue already has a `## Factory plan` comment, this is a re-plan: reuse the branch it names.

## 2. Draft

Launch one `factory-spec-writer` subagent per issue, in parallel, no more than 5 at once. Give each the issue number, title, body, comments, and the CLAUDE.md commands.

The spec writer runs on Fable, because a plan is the cheapest place to buy quality: one run per issue, read by a human, and everything built afterwards inherits its mistakes. If a launch fails because that model isn't available or is rate-limited, launch that issue's writer again with the Agent tool's `model` option set to `opus` (conventions.md, "Running subagents"), and name the model each plan was written on in the report.

If one returns an XL split proposal instead of a plan, post it as a `## Factory decision` comment, label the issue `factory:needs-human`, and skip the rest of the steps for that issue.

## 3. Checkpoint (with-you mode only)

**Always link the plan.** Before you show the human a draft, run step 4 for it (branch, commit and push the plan file) so it can be read on GitHub. Every time you show a plan, first or revised, give the human the link `https://github.com/<REPO>/blob/<branch>/<plan file path>` along with the summary. When a revision comes back, commit it to the same branch (`docs(#<n>): revise factory plan`), push, and link it again. Never ask the human to approve a plan they haven't been given a link to.

Show the human, in about 15 lines or fewer: the plan link, the size, the approach, the scope fence, the human steps, and the open questions. Ask the open questions with the AskUserQuestion tool (the popup), one question per open question, with the plan's recommended default as the first option. Every question in this command goes through the popup, as conventions.md ("Asking a human") describes. Where the recommended default departs from how the repo already does the same thing, say so in that option's description. Wait for answers. Send the answers back to the same `factory-spec-writer` to revise the plan, push the revision, then show the revised plan's link and summary and ask with AskUserQuestion: "Approve this plan for build?"

Don't plan around unanswered product questions. If the human would rather answer later, keep the questions in the plan and continue.

**Design.** If the plan's `Needs design` line is yes (it changes screens a user sees), ask with the popup before the approval question, as two questions in one call: "This changes <screens>. Include design?" (Yes / No) and "How many design options?" (3 (Recommended) / 1 / 2 / 4). Hold the answer until the branch exists, then run step 4a.

## 4. Branch, commit, push

In with-you mode this runs during step 3, before the plan is first shown, and again for each revision. In batch mode it runs after step 2.

For each plan, one issue at a time:

1. Branch name from the conventions (`factory/<n>-<slug>`, using the plan's branch slug), or the existing branch on a re-plan.
2. Open a worktree on it as conventions.md describes: a new branch from `origin/$BASE_BRANCH`, or the existing branch on a re-plan.
3. Write the plan to the plan file (`plans/<n>-<slug>.md` by default, or the `Factory plan dir:` and `Factory plan file:` from CLAUDE.md). On a re-plan, overwrite the file; git history keeps the old version.
4. Commit only that file: `docs(#<n>): factory plan — <issue title>` (re-plan: `docs(#<n>): revise factory plan`).
5. Push: `git -C <worktree> push -u origin <branch>`. In with-you mode, keep the worktree until the plan is approved or the human stops revising, then remove it.

## 4a. Design (when included)

For each plan where design is included, follow `.claude/commands/factory/design.md` steps 3–5 on its branch: write the brief, create the options, and link them from the plan's `### Design` section. In with-you mode, show the options and ask with the popup which one to build, one choice per option plus "Pick later" (with four options, leave "Pick later" out, as design.md step 6 describes); on a pick, run that file's step 6.

In batch mode without `--design`, set the plan's design status to "not decided" and add an open question: "Include design for <screens>? Run `/factory:design <n>`."

An issue whose design is still waiting for a pick stays `factory:planned`, even if the human approves the rest of the plan.

## 5. Link it from the issue

Post a `## Factory plan` comment on the issue:

```markdown
## Factory plan

**Plan:** [<plan file path>](https://github.com/<REPO>/blob/<branch>/<plan file path>)
**Branch:** `<branch>`
**Size:** <size> · **Expected reviewers:** <list>
**Design:** <options with links, the chosen option, "skipped", or "not decided">

<the plan's summary>

**Human steps**
- <who does what, and by when: before the build, before merge, or before release> (or "None")

**Open questions**
- [ ] <question, with its options and the recommended one first> (or "None")

To change the plan, edit the file on the branch. Answers and notes left as comments here are read by `/factory:build`. Add `factory:ready` to approve.
```

On a re-plan, start the comment with "Supersedes the plan above." Never edit a human's comment.

Then set the label:

- Approved in the session (with-you mode): add `factory:ready`, and add "Approved in session by @<login>" under the heading.
- Otherwise: add `factory:planned`.

Remove `factory:needs-human` and the other stage label if present.

## 6. Report

A short table: issue, size, branch, open questions, link to the plan file on GitHub, link to the comment. End with what happens next: approved issues can run `/factory:build <n>`; the rest need `factory:ready` once a human approves them.
