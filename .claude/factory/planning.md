# Factory planning procedure

The `factory-spec-writer` agent plans with this procedure and template for `/factory:plan`. `/factory:plan` commits the result to the issue's branch as the plan file, and `/factory:build` builds from it.

A human reads and approves every plan before code is written, so write for that reader: specific, scannable, and honest about what's unclear. The builder should be able to follow the plan without re-deciding anything.

## Procedure

1. **Read `CLAUDE.md`.** Use the "Commands the factory runs" section, the project rules, any orientation or review-hotspot notes, and the `### Planning` lessons under `## Factory lessons`. Those lessons come from earlier builds where a plan missed something; apply each one that fits this issue.
2. **Copy the acceptance criteria word for word.** If the issue groups them (for example into implementation and test criteria), keep the groups. If the issue has none, derive them and mark each one "(derived)" so the human checks it.
3. **Explore just enough code.** Find the entry points, an existing feature whose patterns you can copy, the tests that cover the area, and recent changes nearby (`git log --oneline -20 -- <path>`). Read files selectively. Find how the repo already does the nearest equivalent thing (where its config and secrets live, how similar features are named and wired) and plan this the same way. A plan that invents a second way to do something the repo already does gets reversed in review.
4. **Size it.**

   | Size | Rough effort | What to do |
   |---|---|---|
   | XS | Under an hour | Plan briefly |
   | S | Under half a day | Plan |
   | M | Up to a day | Plan |
   | L | More than a day | Plan, and recommend a split with the pieces named |
   | XL | Several days, or scope unclear | Don't plan. Propose a split into stories instead |

   Big builds are where agents drift, so lean toward splitting.
5. **Fence the scope.** List the files you expect to change. The builder treats anything outside that list as needing a reason.
6. **Pick a test for every criterion.** Name the test file and case (new or existing), the level (unit, integration, system, browser), and what it asserts. Every criterion maps to at least one step and one test, because that mapping is what the reviewers and the approver check later. For code that can run more than once or at the same time (webhook handlers, background jobs, retries, double submits, payment callbacks), also name a test for the repeated, out-of-order or concurrent case. These are the bugs that review after the PR has found most often.
7. **Separate what only a human can do.** Some steps are out of an agent's reach: secrets and credentials, hosting and third-party dashboards, anything that needs access the session doesn't have. Keep the approach the repo already uses and list those steps under `### Human steps`, saying who does what and whether it must happen before the build, before merge or before release. Don't redesign the change around what an agent can't reach. If that seems necessary, make it an open question that names the convention the plan would be leaving.
8. **List open questions.** Put product decisions you can't settle from the issue or the code here. Don't guess at them. Write each so it can be answered by choosing: give two to four options with your recommended default first, because `/factory:plan` asks them in a popup.
9. **Flag design work.** Set `Needs design: yes` when the change adds or reworks screens a user sees, and list those screens and states. Copy changes, small tweaks to an existing screen, and changes that follow a design the issue already links are usually no.
10. **Suggest a branch slug:** 3–5 kebab-case words describing the work, such as `csv-invoice-export`.

## Plan template

```markdown
## Factory plan

**Issue:** #<n> — <title>
**Branch slug:** <csv-invoice-export>
**Size:** XS | S | M | L — <one-line reason>

### Summary
<2–3 sentences: what changes and why>

### Acceptance criteria → steps → tests
| # | Criterion | Steps | Test (file · case · level) |
|---|---|---|---|
| 1 | <criterion, verbatim> | <step numbers> | <spec/models/invoice_spec.rb · "rounds tax to cents" · unit> |

### Steps
1. <concrete change, naming files and functions>
2. ...

### Design
**Needs design:** yes — <screens and states> | no
**Status:** not decided
<!-- /factory:design fills this in with the design link, the options, then the chosen option and its snapshot -->

### Scope fence
- `<path>` — <what changes>

### Risks and edge cases
- <risk> → <how the plan handles it>

### Human steps
- <who does what> · <before the build | before merge | before release> (write "None" if there are none)

### Expected reviewers
security: yes/no — <why> · ux: yes/no · ui: yes/no

### Open questions
- [ ] <question for a human> · options: <recommended default> / <alternative> (write "None" if there are none)
```

For XL, return this instead of a plan:

```markdown
## Factory decision

**Needs a human:** this story is too big to build in one pass. Proposed split:
1. <story title> — <one line of scope>
2. ...
```
