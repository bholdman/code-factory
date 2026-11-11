# Factory audit rulebook

This is the single source of review rules for `/factory:pr-audit` and the `factory-reviewer-code` agent. Detection rules live here once. Commands and agents never copy them, so a rule change lands everywhere at once.

If the repo has its own rulebook at `.claude/rules/audit-rulebook.md`, use that instead; it's the team's own version. This file uses the same section numbers (§1–§5), so either works with the factory.

Project rules in `CLAUDE.md` (project rules, orientation block, review hotspots) bind with the same force as this file, and win where they conflict.

## Severity

| Severity | In factory reviews | Meaning |
|---|---|---|
| High | blocker | Wrong behavior, data loss or exposure, a security hole, or a stated criterion with failing or missing tests |
| Medium | major | Will cause bugs or slow the team down soon: missed edge cases, broken patterns, scope creep, risky migrations |
| Low | minor | Polish: naming, small duplication, clarity |

A metric alone is never a finding. "Method is 48 lines" isn't a finding. "`InvoiceBuilder#call` mixes tax math, PDF rendering and email delivery, so a tax change can break delivery" is.

## §1 Design and structure (application code)

- **1.1 One reason to change.** A function, class or component mixing unrelated responsibilities. These defaults prompt a closer look: function over 30 lines, class or module over 300 lines, more than 4 parameters, nesting deeper than 3 levels. Medium when the mixing is real.
- **1.2 Duplication.** Logic copied rather than shared, where the copies must change together. Medium; Low for small copies.
- **1.3 Layering.** Business logic in controllers, views or components; data access scattered outside the established layer. Medium.
- **1.4 Naming.** Names that mislead about what something does or holds. Low; Medium when misleading enough to cause misuse.
- **1.5 Leftovers.** Unused code, commented-out blocks, debug output, TODOs for the current change. Low.
- **1.6 Comments.** Comments explain why, not what. Flag doc-block comments only where the project's rules forbid them. Low.
- **1.7 Consistency.** New code ignores an established pattern in the same area, such as error format, service objects, hooks, or state management. Medium.

## §2 Correctness and error handling (application code)

- **2.1 Edge cases.** Nulls and empties, boundaries, time zones, currency and rounding, the last page of a list. High when users would see it; Medium otherwise.
- **2.2 Errors.** Swallowed exceptions, broad rescues or catches, errors returned as success, missing error states in the UI. High when a failure gets hidden.
- **2.3 Concurrency and idempotency.** Races on shared records, jobs or webhooks that aren't safe to retry, missing locks or unique constraints. Check every changed entry point that can run more than once or at the same time (webhook handlers, background jobs, retried requests, double submits, callbacks) against four cases: it runs twice, it runs out of order, it runs concurrently with itself, it fails halfway. A check and a write in separate statements, with no lock or constraint between them, is the usual cause. High.
- **2.4 External calls.** No timeout, no retry where one is needed, failures not handled. Medium.
- **2.5 Contracts.** A changed API response, event payload or function signature without updating its callers. High.

## §3 Migrations and data

- **3.1 Reversible.** A migration can roll back, or its irreversible step is explicit and justified. Medium.
- **3.2 Safe on real data.** Operations that lock large tables (a new non-null column without a default, an index not built concurrently where the database supports it), or backfills done inline instead of in batches. High.
- **3.3 Integrity.** Database constraints and indexes match the validations and uniqueness rules in code. Medium.
- **3.4 Deploy order.** Schema and data changes are separate steps, and the old code still runs against the new schema. Medium.

## §4 Security and performance

- **4.1 Access control.** Every new entry point checks the caller and the caller's right to this specific record. High.
- **4.2 Injection and escaping.** User input reaching SQL, shell, templates or HTML without parameterization or escaping. High.
- **4.3 Secrets and personal data.** None in code, logs, errors or fixtures; responses return only what the caller needs. High.
- **4.4 Unvalidated input.** Mass assignment, or request data reaching persistence without validation. High.
- **4.5 Queries.** N+1 queries, unbounded queries or loads, missing pagination, queries inside loops. Medium; High on hot paths.
- **4.6 Caching.** Stale-cache risk or missing invalidation. Medium.
- **4.7 Dependencies.** New packages are justified, maintained and pinned. Medium.

## §5 Tests (application and test files)

- **5.1 Criteria covered.** Each acceptance criterion has a test that would fail if the change were reverted. Missing: High.
- **5.2 Observed red.** New tests were seen failing before the fix. A test that couldn't have failed proves nothing. Medium.
- **5.3 Behavior over implementation.** Tests assert outcomes, not private calls or internal structure. Medium.
- **5.4 Determinism.** No sleeps, real clocks, real network calls, order dependence, or state shared between tests. Medium.
- **5.5 Edge cases.** The §2 edge cases that matter have tests, including the repeated or concurrent case for an entry point §2.3 covers. Medium.
- **5.6 Disabled tests.** Focused tests (`.only`, `fit`, `focus: true`) are High, because they silently skip the rest of the suite. Skipped or commented-out tests are Medium.
- **5.7 Test data.** Minimal fixtures and factories, with no reliance on production-like seeds. Low.

## Thresholds

Override any number above in `CLAUDE.md` under "Factory settings".
