# budgets — reserved for Beta 1

Not implemented yet. Beta 0 ("local deterministic money engine") covers
tracking only — see `docs/19_PRIVATE_BETA_BUILD_PLAN.md`, Beta 0 scope.

Beta 1 ("Daily Use") adds monthly/category budgets on top of the
transaction ledger this stage builds. The `budgets` and
`budget_categories` tables from `docs/03_DATABASE_SCHEMA.md` are not part
of the Beta 0 schema (`lib/core/database/tables.dart`) — see
`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §6 for what Beta 0's schema does
and does not include, and why.

When this feature is built, follow the same `data/ domain/ presentation/`
structure as `features/transactions/`.
