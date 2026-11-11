---
description: Factory — list open factory issues grouped by stage, oldest first, flagging stalled builds, merged PRs whose issue is still open, and leftover labels
disable-model-invocation: true
---

# /factory:status

Read-only. Make no changes. Read `.claude/factory/conventions.md` for the REST calls and set `REPO`.

For each stage label (`factory:needs-human`, `factory:planned`, `factory:in-review`, `factory:building`, `factory:ready`), list its open issues:

```bash
gh api "repos/$REPO/issues?state=open&labels=<label>&per_page=100" --paginate \
  -q '.[] | select(.pull_request == null) | [.number, .title, .updated_at, .html_url] | @tsv'
```

Show the groups in that order, oldest first within each, and say what each group is waiting for:

- `factory:needs-human`: quote the question from the issue's latest `## Factory decision` comment, so it can be answered from this list.
- `factory:planned`: waiting for a human to read the plan and add `factory:ready`.
- `factory:in-review`: add the PR for the issue's branch (the branch is in its latest `## Factory plan` comment), looked up with `state=all`. Then flag two cases apart. If the PR merged and the issue is still open, the PR body probably lacks `Closes #<n>`, and the issue needs closing by hand. If the PR closed without merging, the work isn't done: the issue stays open, its label is stale, and it needs a new plan or build.
- `factory:building`: flag anything not updated in more than 24 hours as possibly stalled; `/factory:build <n>` can resume it.
- `factory:ready`: approved and waiting for `/factory:build <n>`.

Then list leftovers: closed issues that still carry a stage label.

```bash
gh api "repos/$REPO/issues?state=closed&labels=<label>&per_page=100" --paginate \
  -q '.[] | select(.pull_request == null) | .number'
```

Give the count and the numbers for each label. They are harmless to the flow, but they clutter label searches; the human can clear them. `/factory:build` removes `factory:in-review` when it sees the merge, so leftovers come from builds whose session had ended by then.
