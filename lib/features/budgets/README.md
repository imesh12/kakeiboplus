# budgets

Implemented in Beta 1 Task 2 — see `docs/14_DECISION_LOG.md` ADR-021 for
the full design rationale (schema, uniqueness strategy, month/timezone
convention, category matching, status thresholds, projection formula).

## What's here

- `domain/budget_month.dart` — `BudgetMonth`, the structured year/month
  value type every budget calculation is anchored to (UTC-only, matching
  the rest of the app's existing convention).
- `domain/budget_status.dart` — `BudgetStatus` and the deterministic
  pace-based classification rule.
- `domain/budget_calculation.dart` — `BudgetCalculation` (the full result
  of evaluating a budget) and `BudgetCalculator.evaluate`, which handles
  the current/historical/future month distinction.
- `presentation/budget_providers.dart` — Riverpod providers wiring the
  repository, the ledger, and the domain layer together
  (`livingCurrencyOverallBudgetProvider` is what the Home dashboard's
  budget card reads).
- `presentation/budgets_screen.dart` — the budget management UI (create/
  edit/remove an overall or category budget for the current month),
  reached from the Profile screen and from the dashboard's budget card.

The `BudgetRepository` (Drift-backed persistence) lives at
`lib/core/database/repositories/budget_repository.dart`, alongside every
other repository in this codebase (`Account`/`Category`/`Transaction`/
`Profile`/`Currency`) — **not** under a `data/` subfolder here. This
deliberately follows the actual established convention this codebase
uses everywhere else rather than the `data/ domain/ presentation/`
structure this README previously (aspirationally, before any of it was
built) suggested — no other feature, including `transactions`, actually
uses that structure either.

## What's still out of scope (unchanged from the original Beta 1 spec)

Savings goals, recurring/rollover budgets, envelope budgeting, FX
conversion across budget currencies, weekly or custom budget periods,
AI-driven insights, and any cloud/sync behavior beyond the inert
`sync_version`/`sync_status` columns every table in this schema already
carries.
