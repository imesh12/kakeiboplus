# goals — reserved for Beta 1

Not implemented yet — see `docs/19_PRIVATE_BETA_BUILD_PLAN.md`, Beta 1
("Daily Use"): savings goals, goal contributions, milestones.

This is also why the Beta 0 navigation shell
(`lib/shared/widgets/app_shell.dart`) has no Goals tab — Decision 12 /
ADR-015 add it as a primary destination only once this feature exists,
rather than shipping a placeholder tab that goes nowhere.

`goals`, `goal_contributions`, `savings_streaks`, and
`savings_milestones` from `docs/03_DATABASE_SCHEMA.md` are not part of
the Beta 0 schema. A goal's target currency must stay stable regardless
of FX movement (ADR-013) — implement that rule here when this feature is
built, following the same `data/ domain/ presentation/` structure as
`features/transactions/`.
