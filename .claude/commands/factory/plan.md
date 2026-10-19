---
description: Factory — plan GitHub issues, create each issue's branch, commit the plan to it and push, then link it from the issue for approval
argument-hint: <issue> [issue...] [--batch]
disable-model-invocation: true
---

# /factory:plan

Arguments: `$ARGUMENTS` (none → ask which issues to plan)

Read `.claude/factory/conventions.md` first. It defines the branch and plan-file rules, labels, comment headings, REST-only GitHub calls and hard limits this command relies on.

Planning is cheap compared to building, and a human reads every plan, so aim for clear and specific over long. Don't write code here; the only file this command commits is the plan.

## Mode

- **With you (default for one issue):** one issue number and no `--batch`. You answer the plan's open questions in the session and can approve it on the spot.
- **Batch:** several issues, or `--batch`. No stops. Open questions stay in each plan for the human to answer on the issue. Use this for unattended cloud runs.

## 1. Fetch

For each issue, read it and its comments (REST calls in conventions.md). Skip any issue labeled `factory:building` or `factory:in-review`, and say so. If an issue already has a `## Factory plan` comment, this is a re-plan: reuse the branch it names.

## 2. Draft

Launch one `factory-spec-writer` subagent per issue, in parallel, no more than 5 at once. Give each the issue number, title, body, comments, and the CLAUDE.md commands.

If one returns an XL split proposal instead of a plan, post it as a `## Factory decision` comment, label the issue `factory:needs-human`, and skip the rest of the steps for that issue.

## 3. Checkpoint (with-you mode only)

Show the human, in about 15 lines or fewer: the size, the approach, the scope fence, and the open questions. Wait for answers. Send the answers back to the same `factory-spec-writer` to revise the plan, then show the revised plan and ask: "Approve this plan for build?"

Don't plan around unanswered product questions. If the human would rather answer later, keep the questions in the plan and continue.

## 4. Branch, commit, push

For each plan, one issue at a time:

1. Branch name from the conventions (`factory/<n>-<slug>`, using the plan's branch slug), or the existing branch on a re-plan.
2. Open a worktree on it as conventions.md describes: a new branch from `origin/$BASE_BRANCH`, or the existing branch on a re-plan.
3. Write the plan to the plan file (`plans/<n>-<slug>.md` by default, or the `Factory plan dir:` and `Factory plan file:` from CLAUDE.md). On a re-plan, overwrite the file; git history keeps the old version.
4. Commit only that file: `docs(#<n>): factory plan — <issue title>` (re-plan: `docs(#<n>): revise factory plan`).
5. Push: `git -C <worktree> push -u origin <branch>`. Then remove the worktree.

## 5. Link it from the issue

Post a `## Factory plan` comment on the issue:

```markdown
## Factory plan

**Plan:** [<plan file path>](https://github.com/<REPO>/blob/<branch>/<plan file path>)
**Branch:** `<branch>`
**Size:** <size> · **Expected reviewers:** <list>

<the plan's summary>

**Open questions**
- [ ] <question> (or "None")

To change the plan, edit the file on the branch. Answers and notes left as comments here are read by `/factory:build`. Add `factory:ready` to approve.
```

On a re-plan, start the comment with "Supersedes the plan above." Never edit a human's comment.

Then set the label:

- Approved in the session (with-you mode): add `factory:ready`, and add "Approved in session by @<login>" under the heading.
- Otherwise: add `factory:planned`.

Remove `factory:needs-human` and the other stage label if present.

## 6. Report

A short table: issue, size, branch, open questions, link to the comment. End with what happens next: approved issues can run `/factory:build <n>`; the rest need `factory:ready` once a human approves them.
