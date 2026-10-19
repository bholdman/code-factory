---
description: Factory — check out an approved plan's branch, build it with specialist review agents, and open a PR for a human to merge
argument-hint: <issue>
disable-model-invocation: true
---

# /factory:build

Issue: `$ARGUMENTS` (none → ask which issue to build)

Read `.claude/factory/conventions.md` first. It defines the branch and plan-file rules, labels, comment headings, REST-only GitHub calls, worktrees, reviewer selection and hard limits this command relies on.

You are the orchestrator. You read the issue, launch the factory subagents, write everything that matters back to GitHub, and move the issue between stages. Subagents do the thinking and the code; only you talk to GitHub. That split keeps one writer on the record and keeps your context small enough to finish a long build.

## 1. Preflight

1. Read the issue and its comments. If it doesn't have `factory:ready`, stop and tell the user. That label is the human's approval, and building without it breaks the process.
2. Find the most recent `## Factory plan` comment and take the branch from it. No plan comment, or the branch doesn't exist on `origin` → stop and suggest `/factory:plan <n>`.
3. Open a worktree on the existing branch as conventions.md describes, and record `$BASE`.
4. Read the plan file on the branch. This is the plan, exactly as it reads now; humans edit it before approving, and their edits win.
5. Collect human notes: comments on the issue posted after that plan comment that don't start with a factory heading. Treat them as clarifications. If one contradicts the plan, or reopens a decision the plan made, escalate (section 5) rather than guess which wins.
6. If the plan still lists open questions that no note answers, escalate.
7. **Design.** If the plan's `### Design` status is "waiting for a pick", "waiting for designs" or "not decided" on a plan that `Needs design`, escalate and ask the human to run `/factory:design <n>`. If an option was chosen, confirm its snapshot folder (`plans/<n>-<slug>-design/`) is on the branch. If the snapshot is missing, escalate rather than build from the text.
8. Move the issue to `factory:building`, removing `factory:ready`.

## 2. Build

Launch `factory-builder` with the issue, the plan file path, the design snapshot path (if any), the human notes, the CLAUDE.md commands, the worktree path, and the branch name. It returns DONE or BLOCKED. On BLOCKED, escalate with its question.

## 3. Review rounds (at most 3)

1. Choose and run reviewers as conventions.md describes.
2. Post `## Factory review — round N`: a table of reviewer, verdict and top findings, plus a line naming any skipped reviewers and why.
3. If all reviewers return PASS, go to approval. A PASS can carry minor findings; they go in the PR.
4. If any return CHANGES and N is under 3, send the blocker and major findings to `factory-builder` as a fix round. Then run the next round with the reviewers that returned CHANGES, plus `factory-reviewer-code`.
5. If there are still CHANGES after round 3, escalate. Three rounds without convergence usually means the plan or the requirement is the problem, and that's a human call.

## 4. Approval

Launch `factory-approver` with the issue, the plan file path, the worktree path, `$BASE`, and every review comment. It returns RECOMMEND MERGE (with a PR body) or ESCALATE.

On RECOMMEND MERGE:

1. Make sure the work is committed, then push the branch.
2. Write the approver's PR body to a file and open the PR from the branch into `$BASE_BRANCH` (REST call in conventions.md), titled `<issue title> (#<n>)`. The body must contain `Closes #<n>`. If a PR already exists for the branch, update its body instead (`gh api -X PATCH repos/$REPO/pulls/<pr> -F body=@<file>`).
3. If CLAUDE.md lists `Factory reviewers:`, request them, leaving out the PR's author, because GitHub rejects self-review requests.
4. Post `## Factory decision` on the issue: "Recommend merge", the PR link, the number of rounds, and what the human should look at first.
5. Move the issue to `factory:in-review`, removing `factory:building`.

## 5. Escalation (from any step)

Push the branch first so no work is lost. Then post `## Factory decision` with:

- **Needs a human**, and the single decision you need, phrased so it can be answered in a comment
- what was tried and where it stopped
- the branch name

Move the issue to `factory:needs-human` and stop. When the human answers (a comment, or an edit to the plan file), they re-add `factory:ready` and start a new build on the same branch.

## 6. Finish

Remove the worktree. Report in chat: the outcome, the PR or decision link, how many review rounds ran, and anything surprising. Suggest `/factory:pr-audit <pr>` if the human wants an independent pass before merging.
