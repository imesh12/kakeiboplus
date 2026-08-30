# Claude First Coding Prompt — Stage 1 / Beta 0

This file captures the architecture decisions approved on 2026-08-30 that
govern the first Beta 0 implementation pass, so any future coding session
(human or AI) can pick up context without re-deriving it. It supplements
`CLAUDE_PROJECT_INSTRUCTIONS.md` (the standing project rules) and
`docs/14_DECISION_LOG.md` (ADR-016 through ADR-020, added alongside this
file). The full audit and rationale live in
`../STAGE1_BETA0_IMPLEMENTATION_PLAN.md`.

## Status at the time this file was written

- `docs/` now holds the promoted Blueprint V2 documentation set — the
  only authoritative documentation. Superseded V1 docs and zip archives
  were moved to `../archive/`, not deleted.
- No Flutter/Dart toolchain is reachable from the AI coding sandbox used
  to write Beta 0 (its network egress cannot reach the hosts that serve
  the Flutter engine / Dart SDK / pub.dev). All Beta 0 code was
  hand-written and could not be run through `flutter analyze`,
  `flutter test`, or `dart run build_runner build` before being
  committed. Treat the first local `flutter pub get` /
  `dart run build_runner build --delete-conflicting-outputs` /
  `flutter analyze` / `flutter test` pass as the real first verification,
  not a formality — see the Beta 0 completion report for exactly what
  still needs local confirmation.
- `android/` and `ios/` platform folders were **not** hand-authored (that
  boilerplate is exactly what `flutter create` generates correctly and
  deterministically; fabricating it by hand risked subtly wrong/outdated
  Gradle, AGP, Kotlin, or Xcode project settings). Generate them locally
  with `flutter create --platforms=android,ios .` from the project root,
  then re-run `flutter pub get`.

## Approved Stage 1 / Beta 0 architecture decisions

1. **Canonical layout** — this directory (`AI-Financial-Coach/`) is the
   project root: `docs/`, `lib/`, `test/`, `android/`, `ios/`,
   `pubspec.yaml` all live directly here. No `mobile/` wrapper.
2. **`lib/` layout** — root-level `lib/`, lean feature set. See ADR-016
   and the updated `docs/00_MASTER_BLUEPRINT.md` §33. Reserved feature
   directories (budgets, goals, fx, receipts, recurring) get a
   `README.md` stating their stage, not empty placeholders.
3. **Money representation** — `Money` = signed 64-bit `int` minor units +
   currency code. Never `BigInt`, never `double`, for authoritative
   money. See ADR-017.
4. **Rounding policy** — ROUND HALF UP when producing a monetary result
   in a target currency. Never round a stored exchange rate itself. See
   ADR-018. Not yet exercised in Beta 0 (no FX conversion happens), but
   the utility and its tests exist.
5. **Cross-currency transfers** — rejected in Beta 0, at both the
   domain/service layer and the UI layer. Same-currency-only. See
   ADR-019.
6. **Forward-compatible schema** — `transactions.deleted_at` /
   `sync_version` (`0`) / `sync_status` (`"localOnly"`), and an empty
   `transaction_exchange_rates` table, exist from schema v1 onward but
   are inert until Stage 6 (sync) and Stage 3 (FX) respectively. No
   speculative foreign keys to tables that don't exist yet
   (`merchants`, `receipts`, `recurring_transactions`). See ADR-020.
7. **Dependencies** — only what Beta 0 actually needs: Riverpod,
   GoRouter, Drift/SQLite, `path_provider`/`path`, `uuid`, `intl`,
   `decimal`, code generation (`build_runner`, `riverpod_generator`,
   `drift_dev`), test/lint tooling. No `flutter_secure_storage` until a
   feature actually needs secure secrets/PIN/auth material.
8. **Currency registry** — seeded with JPY, KRW, VND, KWD, LKR, NPR, INR,
   BDT, MMK, QAR, CAD, EUR, USD. `minor_units` always comes from this
   metadata, never a hard-coded assumption in formatting/parsing code.
9. **Navigation** — Beta 0 ships Home / Activity / Add / Profile. No
   Goals tab yet (added when Beta 1 implements goals). The Add sheet
   only enables Expense / Income / Transfer; Receipt and Goal
   Contribution stay absent rather than pretending to work.
10. **Scope discipline** — no OCR, no FX network calls, no live rates, no
    cloud auth, no sync, no AI, no bank connections, no remittance, no
    family sharing in Beta 0. The schema/domain preparation listed above
    (items 6 and 8) is explicitly the only exception, and it is inert.

## Hard release gates (do not consider Beta 0 done without these passing)

See `docs/19_PRIVATE_BETA_BUILD_PLAN.md` (Beta 0 exit criteria) and
`docs/09_TESTING_STRATEGY.md`, sharpened by the 2026-08-30 decisions:

- No `double` anywhere in authoritative money arithmetic.
- JPY, KRW, VND (all 0 minor units), KWD (3 minor units), and a
  representative 2-decimal currency all round-trip correctly.
- A transfer never appears in income or expense totals.
- A transfer correctly decreases the source account balance and
  increases the destination account balance.
- A cross-currency transfer is rejected at both layers (ADR-019).
- Transactions persist across an app/database restart.
- Deleted (`deleted_at` set) transactions are excluded from active
  totals.
- Arithmetic between `Money` values of mismatched currencies throws
  rather than silently coercing.

## Working method for this and future stages

Implement incrementally; after each layer, run the formatter, analyzer,
and relevant tests before moving on (this sandbox could not do that live
for Beta 0 — see "Status" above; a local session should). Don't wait
until the end to test everything. Stop and ask before changing the
technology stack, money representation, database technology, state
management, routing framework, offline-first behavior, currency
semantics, or any documented financial invariant. Ordinary implementation
details already resolved by the blueprint or the decisions above don't
need re-approval.
