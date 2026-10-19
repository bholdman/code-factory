---
description: Factory — list open factory issues grouped by stage, oldest first, flagging stalled builds
disable-model-invocation: true
---

# /factory:status

Read-only. Make no changes. Read `.claude/factory/conventions.md` for the REST calls and set `REPO`.

For each stage label (`factory:needs-human`, `factory:planned`, `factory:in-review`, `factory:building`, `factory:ready`), list its open issues:

```bash
gh api "repos/$REPO/issues?state=open&labels=<label>&per_page=100" --paginate \
  -q '.[] | select(.pull_request == null) | [.number, .title, .updated_at, .html_url] | @tsv'
```

Show the groups in that order, oldest first within each. Flag anything in `factory:building` that hasn't been updated in more than 24 hours as possibly stalled. For `factory:in-review` items, add the open PR for the issue's branch (the branch is in its latest `## Factory plan` comment).
