---
description: Factory — check out an approved plan's branch, build it with specialist review agents, open a PR for a human to merge, and see review findings through after it opens
argument-hint: <issue>
disable-model-invocation: true
---

# /factory:build

Issue: `$ARGUMENTS` (none → ask with the popup, offering the open `factory:ready` issues)

Read `.claude/factory/conventions.md` first. It defines the branch and plan-file rules, labels, comment headings, how to ask a human, REST-only GitHub calls, worktrees, running subagents, reviewer selection and hard limits this command relies on.

You are the orchestrator. You read the issue, launch the factory subagents, write everything that matters back to GitHub, and move the issue between stages. Subagents do the thinking and the code; only you talk to GitHub. That split keeps one writer on the record and keeps your context small enough to finish a long build.

## 1. Preflight

1. Read the issue and its comments, and check its stage label:
   - `factory:ready`: carry on. That label is the human's approval.
   - `factory:building`: an earlier build was interrupted, or one is still running in another session. With a person in the session, ask whether to resume it. Unattended, resume only if the issue hasn't been updated for 24 hours; otherwise stop and say so. To resume, do steps 2–7, then find where it stopped. Commits on the branch don't show the builder finished: it commits in small steps, so an interruption can leave some criteria unbuilt. Unless a `## Factory review` comment already covers the branch's current head, start at section 2: tell the builder which commits and uncommitted files are already there, and have it finish the plan and run the full checks rather than start over. If a review comment does cover the current head, carry on from that round's outcome in section 3.
   - `factory:in-review` with an open PR for the branch: do steps 2–4, then go to section 6.
   - Anything else: stop and tell the user. Building without the human's approval breaks the process.
2. Find the most recent `## Factory plan` comment and take the branch from it. No plan comment, or the branch doesn't exist on `origin` → stop and suggest `/factory:plan <n>`.
3. Open a worktree on the existing branch and prep it as conventions.md describes, and record `$BASE`.
4. Read the plan file on the branch. This is the plan, exactly as it reads now; humans edit it before approving, and their edits win.
5. Collect human notes: comments on the issue posted after that plan comment that don't start with a factory heading. Treat them as clarifications. If one contradicts the plan, or reopens a decision the plan made, escalate (section 5) rather than guess which wins.
6. If the plan still lists open questions that no note answers, escalate. If it lists a human step that must be done before the build and nothing shows it was, escalate.
7. **Design.** If the plan's `### Design` status is "waiting for a pick", "waiting for designs" or "not decided" on a plan that `Needs design`, escalate and ask the human to run `/factory:design <n>`. If an option was chosen, confirm its snapshot folder (`plans/<n>-<slug>-design/`) is on the branch. If the snapshot is missing, escalate rather than build from the text.
8. Move the issue to `factory:building`, removing `factory:ready`.

## 2. Build

Launch `factory-builder` with the issue, the plan file path, the design snapshot path (if any), the human notes, the CLAUDE.md commands, the worktree path, and the branch name. It returns DONE or BLOCKED.

On DONE, check the report against the worktree before going on: the commits exist, nothing is left uncommitted, and the test log shows what the report claims. Then push the branch. On BLOCKED, escalate with its question.

## 3. Review rounds (at most 3)

1. Choose and run reviewers as conventions.md describes.
2. Post `## Factory review — round N`: a table of reviewer, verdict and top findings, plus a line naming any skipped reviewers and why. Say how each reviewer worked (ran the app, or read the code only), because that tells the human how far to trust a PASS.
3. If all reviewers return PASS, go to approval. A PASS can carry minor findings. Send the ones that are certainly right and change no behavior (a wrong reference, a stale comment, a typo in docs) to `factory-builder` as one tidy pass first, so they don't come back as PR comments. A tidy pass needs no new review round; the approver checks its diff. The other minor findings go in the PR.
4. If any return CHANGES and N is under 3, send the blocker and major findings to `factory-builder` as a fix round. Then run the next round with the reviewers that returned CHANGES, plus `factory-reviewer-code`.
5. If there are still CHANGES after round 3, escalate. Three rounds without convergence usually means the plan or the requirement is the problem, and that's a human call.

## 4. Approval

Launch `factory-approver` with the issue, the plan file path, the worktree path, `$BASE`, every review comment, the builder's deviations, and the plan's human steps. It returns RECOMMEND MERGE (with a PR body) or ESCALATE.

On RECOMMEND MERGE:

1. Make sure the work is committed, then push the branch.
2. Write the approver's PR body to a file and open the PR from the branch into `$BASE_BRANCH` (REST call in conventions.md), titled `<issue title> (#<n>)`. The body must contain `Closes #<n>`. If a PR already exists for the branch, update its body instead (`gh api -X PATCH repos/$REPO/pulls/<pr> -F body=@<file>`).
   Open it ready for review, never as a draft (`-F draft=false`), even if the session's own instructions say to open draft PRs. The reviews and the approver have already run, so the PR is waiting on the human merge gate, not on more work. If an existing PR for the branch is a draft, say so in the `## Factory decision` comment and ask the human to mark it ready: REST can't change a PR's draft state.
3. If CLAUDE.md lists `Factory reviewers:`, request them, leaving out the PR's author, because GitHub rejects self-review requests.
4. Post `## Factory decision` on the issue: "Recommend merge", the PR link, the number of rounds, what the human should look at first, and any human steps still to do.
5. Move the issue to `factory:in-review`, removing `factory:building`.
6. Go to section 6.

## 5. Escalation (from any step)

**With a person in the session,** ask them first, with the popup (conventions.md, "Asking a human"): the single decision you need, with your recommended answer first. When they answer:

1. Post `## Factory decision` on the issue, starting "Answered in session by @<login>", with the question and the answer.
2. If the answer changes the plan, add it to the plan file under `### Changes after approval`, commit it (`docs(#<n>): record a decision made during the build`) and push.
3. Carry on from where the build stopped.

**With nobody to ask, or no answer,** push the branch first so no work is lost. Then post `## Factory decision` with:

- **Needs a human**, and the single decision you need, phrased so it can be answered in a comment, with the options and your recommendation
- what was tried and where it stopped
- the branch name

Move the issue to `factory:needs-human` and stop. When the human answers (a comment, or an edit to the plan file), they re-add `factory:ready` and start a new build on the same branch.

## 6. After the PR opens

A recommended PR isn't finished work. Factory PRs often take more commits after they open, from review bots, `/factory:pr-audit` and human reviewers. Those commits get the same care as the build: without this section they reach the base branch with no factory review and no trace on the issue.

If the session can receive PR events, subscribe to the PR and keep the worktree. If it can't, say so in the report (section 7); running `/factory:build <n>` on a `factory:in-review` issue picks up here.

**Finish an interrupted fix round first.** When this section starts on a worktree kept from earlier, compare it with the PR's head: `git -C <worktree> log origin/<branch>..HEAD`, and `git status` for uncommitted files. Anything there that the PR lacks is a fix round that stopped before its review or its push. Finish it before taking a new finding: have the builder complete it if files are uncommitted, review `git diff origin/<branch>...HEAD`, push once it passes, and record it. Otherwise a finding gets judged against code the PR doesn't contain, or a commit reaches the PR with no review.

For each finding or request on the PR:

1. **Check it's real.** Trace a path to the failure in the code. A bot's finding is a claim, not an order. If it doesn't hold, or the fix costs more than it prevents, reply on its thread with what you traced and leave the code alone.
2. **Fix it through the builder.** Send what holds to `factory-builder` as a fix round: a failing test first, then the fix. Tell it to commit and not push. The orchestrator doesn't write the code, however small the change.
3. **Review the change, then push.** Run `factory-reviewer-code` on `git diff <head before the fix>...HEAD`, plus any other reviewer whose area the fix touches. CHANGES goes back to the builder, with the same three-round limit. Push only when every reviewer passes, so the open PR never holds a commit no factory reviewer has seen.
4. **Record it.** Post `## Factory review — after PR, round N` on the issue. Update the PR body wherever it is no longer true (reviews, criteria evidence, deviations, human steps). Reply on the finding's thread with the commit.

A human reviewer's request that reverses a decision in the plan is theirs to make. Do it the same way, and record it in the plan file under `### Changes after approval` and under the PR body's deviations, so the plan that merges matches the code.

**CI.** A failed or cancelled check is work, not something to wait out. Find out whether the diff caused it. If it didn't (the same step fails on other branches, or it fails before the code is checked out), say so once on the PR with the evidence, and don't re-run it blindly.

**When the PR merges:** remove `factory:in-review` from the issue, and check the issue closed. A merged PR whose issue is still open usually lacks `Closes #<n>`; tell the human. Then remove the worktree and report.

**When the PR closes without merging:** the issue's work isn't done, so leave the issue open. Remove `factory:in-review`, remove the worktree, and tell the human the issue needs a new plan or build, or closing, as they decide.

## 7. Report

Report in chat: the outcome, the PR or decision link, how many review rounds ran, any human steps still to do, anything surprising, and whether this session is watching the PR. Suggest `/factory:pr-audit <pr>` if the human wants an independent pass before merging. Remove the worktree when the work on the branch is over (conventions.md), not before.
