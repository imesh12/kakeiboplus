# recurring — reserved for Beta 1 / Stage 5

Not implemented yet — no recurring bills/income, upcoming-commitment
tracking, or reminders. See `docs/19_PRIVATE_BETA_BUILD_PLAN.md` Beta 1
(basic recurring bills) and Stage 5 (full recurring + motivation).

The `recurring_transactions` table from `docs/03_DATABASE_SCHEMA.md` is
not part of the Beta 0 schema, and `transactions.recurring_transaction_id`
does not exist in Beta 0 either (Decision 8 — no speculative foreign keys
to tables that don't exist yet).
