# fx — reserved for Beta 2 / Stage 3

Not implemented yet. No FX provider integration, live rate fetching, or
currency conversion exists in Beta 0 — see Decision 13
(`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §16) and
`docs/19_PRIVATE_BETA_BUILD_PLAN.md` Beta 2.

Two pieces of groundwork already exist for this feature to build on,
approved as part of the Stage 1 decisions (`docs/14_DECISION_LOG.md`
ADR-018, ADR-020):

- `lib/core/money/money_rounding.dart` — the ROUND HALF UP rounding
  policy for producing a monetary result in a target currency. Rates
  themselves must never be rounded — only the converted amount.
- `lib/core/database/tables.dart` — the `transaction_exchange_rates`
  table exists in schema v1 but is never written to yet.

Beta 0 also restricts account transfers to same-currency pairs only
(ADR-019, enforced in `lib/core/database/repositories/transaction_repository.dart`
and `lib/features/transactions/presentation/add_transaction_screen.dart`).
Lifting that restriction for cross-currency transfers is this feature's
job, once it exists — see ADR-019 for exactly what must be preserved
(source/destination amount and currency, rate, rate source, rate
timestamp).
