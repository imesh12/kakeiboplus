# Architecture Decision Log

## ADR-001 — Flutter

Decision: Use Flutter for Android/iOS first.

Reason: One UI codebase, strong native integration, mature ecosystem.

## ADR-002 — FastAPI

Decision: Use FastAPI for backend APIs.

Reason: Python ecosystem integrates naturally with OCR, analytics and AI.

## ADR-003 — PostgreSQL

Decision: Use PostgreSQL as the authoritative financial database.

Reason: Strong transactional guarantees and relational modeling.

## ADR-004 — Deterministic-first finance engine

Decision: All balances, totals and core projections are calculated by application code.

Reason: Financial correctness must not depend on probabilistic model output.

## ADR-005 — AI gateway

Decision: Use a provider abstraction.

Reason: Avoid vendor lock-in and allow cost/privacy routing.

## ADR-006 — Offline-first transaction capture

Decision: Transactions can be entered locally and synchronized later.

Reason: Financial capture should not fail because of poor connectivity.

## ADR-007 — Receipt confirmation

Decision: OCR results require confirmation when confidence is below defined thresholds.

Reason: Prevent silent financial-data corruption.

## ADR-008 — International-first money model

Decision: Home/current country and home/living currency are foundational profile concepts.

Reason: Early users may live in a different country from their home country, and adding this after transaction design would create expensive migrations.

## ADR-009 — Multi-currency is P0

Decision: Multi-currency architecture starts with the core money engine, not an advanced phase.

Reason: Accounts, transactions, goals, receipts, analytics, and budgets all depend on correct currency semantics.

## ADR-010 — Historical FX snapshots

Decision: Converted historical transaction values use stored FX snapshots and are not rewritten when current market rates change.

Reason: Financial history must be reproducible and auditable.

## ADR-011 — FX rates are reference data

Decision: Display provider/source timestamps and describe FX values as reference rates unless an execution provider explicitly guarantees otherwise.

Reason: Bank/card/remittance execution rates can differ from market reference quotes.

## ADR-012 — Currency precision metadata

Decision: Currency metadata defines minor units; the system never assumes two decimal places.

Reason: JPY/KRW and KWD demonstrate why a universal two-decimal model is incorrect.

## ADR-013 — Savings goal currency is stable

Decision: A goal is anchored to its target currency.

Reason: Exchange-rate changes should not silently change what the user is trying to save.

## ADR-014 — AI deferred from private-beta core

Decision: Conversational AI is not required for the first friends-and-family build.

Reason: The beta should first prove transaction reliability, savings usefulness, FX utility, OCR quality, and retention.

## ADR-015 — Compact private-beta navigation

Decision: Private beta uses Home, Activity, Add, Goals, and Profile as primary destinations.

Reason: Reduce cognitive load and avoid promoting unfinished AI/analytics areas.
## ADR-016 — Root-level Flutter source layout

Decision: `lib/` lives at the repository root. There is no `mobile/`
wrapper directory, and the Beta 0 feature set inside `features/` is the
lean list from `CLAUDE_PROJECT_INSTRUCTIONS.md`, not the broader list
originally sketched in `00_MASTER_BLUEPRINT.md` §33.

Reason: this repository holds exactly one mobile application. A `mobile/`
wrapper only earns its keep in a monorepo with multiple deployable
packages (e.g. `mobile/`, `backend/`, `admin_web/` as siblings) — which
this repository's actual top-level layout does not have inside the
Flutter project itself. The wrapper would add a directory level with no
present or planned use. This ADR supersedes the `mobile/lib/...` example
in `00_MASTER_BLUEPRINT.md` §33, which has been updated to match.

Status: Approved 2026-08-30 (Stage 1 architecture decisions).

## ADR-017 — Money representation: signed 64-bit integer minor units

Decision: `Money` stores its magnitude as a native Dart `int` (signed
64-bit on all platforms Flutter targets) counting whole minor units of a
given currency — never `BigInt`, never `double`, for any authoritative
financial value.

Reason: SQLite's native column affinity is a signed 64-bit `INTEGER`, and
Drift maps directly onto it — storing `BigInt` would require a TEXT/BLOB
encoding and custom (de)serialization for no realistic benefit, since
personal-finance amounts and multi-year aggregate sums stay comfortably
within the 64-bit range (about ±9.2×10^18 minor units). Native `int`
keeps `SUM`, `ORDER BY`, indexing, and comparisons cheap and simple.
`double` remains categorically forbidden per the project's core money
rule. Should the application ever need values genuinely outside the
signed-64-bit range, that will require its own ADR before it happens —
it is not assumed here.

Status: Approved 2026-08-30 (Stage 1 architecture decisions). Supersedes
the `BigInt`-based `Money` sketch in the Stage 1 planning document
(`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §5), which predates this ADR.

## ADR-018 — Monetary rounding policy: ROUND HALF UP

Decision: whenever an exact decimal value must be rounded into a target
currency's minor units, use ROUND HALF UP (round half away from zero).
Examples: JPY 123.5 → 124; USD 12.345 → 12.35; KWD 1.2345 → 1.235.

This rounding is applied **only** when producing a monetary *result* in a
target currency (e.g. a future FX-converted amount). It is never applied
to a stored exchange rate itself — rates are preserved at full provider
precision, and only the resulting converted money is rounded. The
historical rate used for any conversion is always preserved alongside the
rounded result, per the existing historical-FX-snapshot invariant.

Reason: the documentation did not previously specify a rounding mode.
Deciding now, before Stage 3 (FX) needs it under time pressure, avoids an
ad hoc choice later. Beta 0 performs no currency conversion, so this
policy is not yet exercised by any production code path, but the utility
implementing it (and its tests) exist from Stage 1 so Stage 3 can build on
a settled foundation.

Status: Approved 2026-08-30 (Stage 1 architecture decisions).

## ADR-019 — Beta 0 supports same-currency account transfers only

Decision: for Beta 0, a transfer is only permitted between two accounts
that share the same `currency_code`. A cross-currency transfer attempt
(e.g. a JPY account to an LKR account) is rejected with a clear,
user-facing message at both the domain/service validation layer and the
UI/form layer — never silently converted, and never accepted by the
domain layer merely because a caller skipped UI validation.

Reason: `03_DATABASE_SCHEMA.md`'s `transactions` row carries a single
`amount`/`currency_code`, which is unambiguous for a same-currency
transfer but does not by itself define what a cross-currency transfer
means (unconverted amount moved as-is? converted via which rate,
recorded how?). Answering that properly requires the FX/exchange-rate
machinery that Beta 0 explicitly does not implement.

When cross-currency transfers are implemented (Stage 3, FX), they must
preserve: source amount, source currency, destination amount, destination
currency, exchange rate, rate source, and rate timestamp — consistent with
the existing historical-FX-snapshot invariant (ADR-010). This is not
redesigned or preemptively implemented during Beta 0.

Status: Approved 2026-08-30 (Stage 1 architecture decisions). Temporary
restriction, expected to be lifted in Stage 3.

## ADR-020 — Beta 0 forward-compatible schema additions

Decision: schema version 1 (Beta 0) includes two elements that are inert
until later stages, to avoid destructive migrations on live user data
when those stages arrive:

1. `transactions.deleted_at`, `transactions.sync_version`, and
   `transactions.sync_status` columns, defaulted to a local-only state
   (`sync_version = 0`, `sync_status = "localOnly"`) and not yet read by
   any sync logic (none exists until Stage 6).
2. A `transaction_exchange_rates` table with the shape described in
   `03_DATABASE_SCHEMA.md`, created but never written to until Stage 3
   (FX). No FX provider integration, live conversion, or rate fetching is
   implemented in Beta 0.

Reason: ADR-009 already establishes that multi-currency architecture
starts with the core money engine rather than an advanced phase, and the
historical-FX-snapshot invariant (ADR-010) depends on this table's shape
existing. Reserving the shape now costs nothing (the table stays empty)
and avoids an awkward schema migration under a live database later.
Speculative *foreign keys* to tables that do not exist yet (`merchants`,
`receipts`, `recurring_transactions`) are explicitly avoided — see
`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §16, corrected by this decision: no
such columns are added to `transactions` until their owning feature
actually lands.

Status: Approved 2026-08-30 (Stage 1 architecture decisions).

## ADR-021 — Beta 1 Task 2 budgets: schema, uniqueness, month, and status model

Decision: Beta 1's budget foundation (schema version 2) is built on the
following deliberate choices, made after inspecting the existing
architecture rather than copying `03_DATABASE_SCHEMA.md`'s aspirational
"V2 Core" `budgets`/`budget_categories` design (which includes
out-of-scope concepts for this task: `period_type`, `rollover_enabled`,
arbitrary `start_date`/`end_date`):

1. **One `budgets` table, not two.** A single row represents either an
   overall (whole-currency) budget or a category budget, discriminated
   by `category_id`'s nullability — the same pattern
   `transactions.destination_account_id` already uses to distinguish a
   transfer from every other transaction type. No `budget_type` column.

2. **Structured `year`/`month` integer columns**, never a `YYYY-MM`
   string or a floating "current month" concept — see
   `lib/features/budgets/domain/budget_month.dart`'s `BudgetMonth` value
   type, which also introduces the first year-range convention in this
   schema (2000-2100 inclusive) since no other table constrains a year.

3. **UTC calendar-month convention, reused unchanged.** Budgets use
   exactly the same UTC month-boundary math
   `dashboard_providers.dart` already established in Beta 1 Task 1
   (`DateTime.utc(year, month)` / `DateTime.utc(year, month + 1) - 1
   microsecond`). `profile.timezone` remains stored but unconsumed by any
   computation anywhere in the app, as it already was — Beta 1 does not
   invent a partial timezone-aware month engine to be the first feature
   that honors it.

4. **Uniqueness is an application-layer invariant, not a database
   constraint.** No table in this schema uses Drift `uniqueKeys` (see
   ADR-019's precedent for currency-match validation living in
   `TransactionRepository` rather than a DB CHECK). `BudgetRepository` is
   the only sanctioned way to write a `budgets` row: `setOverallBudget`/
   `setCategoryBudget` are upserts that look for an existing *active*
   (`deleted_at IS NULL`) row matching the profile/currency/year/month
   (/category) key and update it in place, or insert a new row if none
   exists. This is an application-layer guarantee, not a
   concurrency-safe database one — acceptable for Beta 1's local-only,
   single-writer-at-a-time scope because every write is centralized
   through this one repository. Because the check only ever considers
   active rows, deleting a budget and then setting a new one for the same
   key always succeeds — the soft-deleted predecessor is simply ignored,
   never a conflict. There is no separate public "insert" method that
   could bypass this.

5. **Exact-category matching only, no subcategory rollup.**
   `categories.parent_id` exists in the schema but is completely
   unpopulated and unenforced — no subcategory UI exists anywhere in the
   app (`CategoryRepository.createCategory` does not even accept a
   `parentId`). A category budget therefore matches only expense
   transactions whose `category_id` equals it exactly. This is the
   safest behavior given the current structure, stated explicitly rather
   than invented silently, and does not touch `parent_id` at all, so it
   is trivially revisitable once subcategories are actually built.

6. **Spent = expense-only, exact scope.** An overall budget's "spent"
   figure is `FinanceEngine.incomeExpenseTotals(...).expense` (already
   excludes transfers and income). A category budget's "spent" figure
   needed a new primitive — `FinanceEngine.categoryExpenseTotal` — since
   the existing `FinanceEngine.categoryTotals` nets income against
   expense per category, which does not satisfy the "income must never
   reduce a category budget's spend" release gate.

7. **Recommended daily spend** (`FinanceEngine.recommendedDailySpend`):
   zero or negative `remaining` → zero, never a negative "allowance".
   Otherwise `remaining.minorUnits ~/ remainingDaysInclusive`, truncating
   integer division, today counted as one of the remaining days — the
   same rounding/inclusion convention `FinanceEngine.dailySpendingPace`
   (Beta 1 Task 1) already established.

8. **Projected month-end spend**
   (`FinanceEngine.projectedMonthEndSpend`): `(spent.minorUnits *
   totalDaysInMonth) ~/ daysElapsedInclusive` — multiplication before the
   single truncating division, not `(spent ~/ daysElapsedInclusive) *
   totalDaysInMonth`, which would truncate twice and can materially
   understate the projection for a small elapsed-day count. Guards
   against silent 64-bit overflow before multiplying. Not defined for a
   month with zero elapsed days (throws `ArgumentError` if called that
   way) — callers must not invoke it for a future month.

9. **Status is a deterministic pace comparison, not an arbitrary
   percentage cutoff.** `expectedSpendSoFar = budgeted.minorUnits *
   daysElapsedInclusive ~/ totalDaysInMonth`; `spent > budgeted` →
   `overBudget`; `spent > expectedSpendSoFar` (but not over budget) →
   `caution`; otherwise `healthy`. A consequence worth noting: for a
   fully-elapsed (historical) month, `daysElapsedInclusive ==
   totalDaysInMonth`, so `expectedSpendSoFar` always equals the full
   budget exactly — a historical month's status can only ever be
   `healthy` or `overBudget`, never `caution` (which specifically means
   "ahead of a *partial* pace").

10. **Current / historical / future month semantics are explicit,
    never undefined arithmetic.** `BudgetCalculator.evaluate`
    (`lib/features/budgets/domain/budget_calculation.dart`) computes
    `daysElapsedInclusive` as: `todayUtc.day` for the current month;
    `month.totalDays` (fully elapsed) for a historical month; `0` for a
    future month. For a future month, `dailyRecommendedSpend`,
    `projectedMonthEndSpend`, and `status` are all left `null`
    ("not applicable") rather than dividing by zero elapsed days or
    fabricating a healthy answer for a month that has not started.
    `budgeted`/`spent`/`remaining` remain real values regardless of
    period, since they need no notion of "today".

11. **Percentage-used is presentation-only and uncapped in text.** The
    budgeted/spent/remaining/daily-recommendation amounts are always
    `Money` (integer minor units). A displayed percentage is derived,
    non-authoritative presentation data — its text is never clamped (an
    overspent budget reads as e.g. "142% used", not hidden behind a false
    "100%"); only a progress bar's *fill fraction* is clamped to 100%,
    purely because a bar cannot render past full. A configured budget of
    zero is never possible in the first place — `BudgetRepository`
    rejects a zero or negative amount before any row is written, so this
    can never divide by zero.

12. **Validation, enforced at the repository layer before any write:**
    amount strictly positive (`InvalidBudgetAmountException` otherwise),
    currency code must be a known `CurrencyRegistry` entry, and
    year/month validity is enforced structurally by `BudgetMonth`'s own
    constructor (the repository's only month API), so an invalid month
    can never reach `BudgetRepository` at all.

13. **Dashboard integration stays living-currency-only.** The Home
    dashboard's budget card reads only the overall budget in the
    profile's *living* currency for the current month
    (`livingCurrencyOverallBudgetProvider`) — a budget configured in any
    other currency, and every category budget, is managed on the new
    Budgets screen (`/budgets`, reachable from Profile and from the
    dashboard card itself) but never merged into or shown on Home. This
    task does not attempt the full dashboard redesign
    `docs/design/dashboard-ui-reference.png` points toward — only the
    budget card's existing empty/configured states gain real numbers.

Status: Approved 2026-09-02 (Beta 1 Task 2).

## ADR-022 — Beta 1 Task 3 savings goals: schema, pace, milestones, and Home selection

Decision: Beta 1's savings goals foundation (schema version 3) is built
on the following deliberate choices. Several correct a first pass of
this plan that this project's owner explicitly rejected during review —
each is noted below, since the rejected reasoning is exactly the mistake
a future change to this area must not repeat.

1. **Two new tables, `savings_goals` and `savings_goal_contributions`,
   added via `onUpgrade`, not `onCreate`.** No existing table changes
   shape and no historical row is touched. `savings_goals.currency_code`
   is permanently anchored at creation — `SavingsGoalRepository.updateGoal`
   never changes it; passing a `targetAmount` in a different currency
   throws `CurrencyMismatchException` (same reject-rather-than-coerce
   precedent as `Money` arithmetic and `AccountRepository.createAccount`)
   and leaves the stored row completely unchanged. `savings_goals.target_date`
   is an optional calendar date, not a genuine instant — see point 3.
   `savings_goal_contributions.currency_code` is **duplicated** from the
   parent goal at write time rather than derived via a join — a small,
   deliberate redundancy that keeps the contribution ledger
   self-describing and matches this schema's existing convention
   (`transaction_exchange_rates` also duplicates rather than joins).
   Both tables get the same forward-compatible `sync_version`/`sync_status`
   columns every other table has carried since ADR-020, and the same
   `deleted_at` soft-delete convention as `accounts`/`transactions`/
   `budgets`. A migration test
   (`test/core/database/savings_goals_migration_test.dart`) builds a v2
   database by hand (raw SQL, cross-checked column-for-column against
   `tables.dart` and the generated `$XyzTable` definitions, plus
   `PRAGMA user_version = 2`), seeds a profile and a budget row, opens it
   with the real (v3) `AppDatabase`, and asserts the new tables exist and
   are usable and that the v2 rows' LOGICAL data survives unchanged
   (field values, not raw database-file bytes — "byte-for-byte" was never
   asserted, since that would require comparing serialized bytes, which
   this test does not do). Known limitation: unlike a real
   migration-testing tool, that hand-authored fixture must be updated by
   hand if `tables.dart`'s v2 shape it mirrors ever changes.

2. **Recommended daily contribution pace CEILS, never floors.**
   `FinanceEngine.recommendedDailyContribution` computes
   `q = remaining.minorUnits ~/ remainingDaysInclusive`,
   `r = remaining.minorUnits % remainingDaysInclusive`, and returns
   `q + (r == 0 ? 0 : 1)` — never the `(x + n - 1) ~/ n` idiom, which can
   overflow before its division ever runs. This is deliberately the
   opposite rounding direction from Task 2's `recommendedDailySpend`
   (which floors, because a *spending allowance* must stay conservative);
   a *savings pace* must instead be sufficient to actually reach the
   goal, so flooring here would silently under-recommend and let a user
   miss their own deadline (e.g. remaining=100/days=3: flooring gives 33,
   and 33×3=99 < 100 — short by 1 — so this must ceil to 34). Only Beta
   1's `recommendedDailyContribution` exists; there is no derived
   weekly/monthly pace anywhere in the domain or UI layer, even as a
   documented "future" note. Semantics: completed → `Money.zero`
   (a real answer, "nothing left to save"); no target date → `null`
   ("not applicable"); a passed, still-unfunded target date → `null`,
   never a fabricated zero (which would misleadingly read as "on track");
   a target date equal to today → `remainingDaysInclusive == 1`, i.e. the
   entire remaining amount is due today; a future date → the ceiling
   formula above.

3. **Calendar-date and instant normalization are two different rules
   for two different kinds of value, and each must use the right one.**
   `goal_target_date.dart`'s `normalizeCalendarDateToUtc` NEVER calls
   `.toUtc()`/`.toLocal()` — it reads `.year`/`.month`/`.day` directly off
   whatever `DateTime` it's given (a date picker typically returns local
   midnight) and re-wraps those three numbers as a UTC midnight, because
   converting the *instant* first can shift which calendar day results,
   depending on the device's UTC offset. A target date is a calendar
   date, not an instant, so this is the only correct normalization for
   it, and it is the ONLY place a target date is ever normalized —
   `SavingsGoalRepository.createGoal`/`updateGoal` both call it at the
   write boundary. A contribution's `contributed_at`, by contrast, IS a
   genuine instant: `SavingsGoalContributionRepository.addContribution`
   correctly normalizes a supplied value via `.toUtc()` (defaulting to
   `DateTime.now().toUtc()` when omitted, matching every other
   repository's convention — there is no separate clock abstraction to
   inject). UI display follows the same split: a target date is
   formatted directly, never `.toLocal()`'d first (that could shift which
   day it displays as, the exact bug this rule exists to prevent);
   `contributed_at` correctly IS `.toLocal()`'d for display, since it
   really is an instant. A regression test proves a `DateTime` with a
   non-UTC/non-midnight time component still normalizes to exactly the
   selected Y-M-D.

4. **`updateGoal`'s `targetDate` reuses drift's own `Value` sentinel**
   (`Value<DateTime?>`), rather than inventing a new wrapper type — this
   project already relies on `Value.absent()` vs `Value(x)` vs
   `Value(null)` everywhere else a Companion update needs to distinguish
   "don't touch" from "set" from "clear", so extending that same idiom to
   the repository's own public method signature is the simplest style
   consistent with the rest of the codebase. `Value.absent()` (the
   default) leaves the stored target date unchanged; `Value(null)`
   explicitly clears it; `Value(someDate)` replaces it (still normalized
   via point 3). All three states are covered by
   `savings_goal_repository_test.dart`.

5. **Goal name validation happens at the repository layer.**
   `SavingsGoalRepository` trims the name and rejects an empty or
   whitespace-only result (`InvalidSavingsGoalNameException`) before any
   write — `"   "` can never be persisted as a stored name. No arbitrary
   maximum length is imposed (nothing in this task's scope calls for
   one).

6. **Milestone-threshold arithmetic is exact and overflow-safe across
   the entire signed-64-bit `Money` domain, computed via integer
   quotient/remainder decomposition — not a casual "multiply by up to
   100."** This corrects the original draft's reasoning ("the headroom
   before overflow is enormous, so no overflow guard is needed"), which
   was rejected during review as unsound: multiplying a near-int64-max
   target by 3 (needed naively for the 75% threshold) can itself
   overflow well before the division that was supposed to bring the
   result back down ever runs. The fix
   (`savings_goal_milestones.dart`) computes each threshold's required
   minor-units value from `target`'s own quotient/remainder against the
   threshold's denominator (4 for 25/50/75%, no division needed for
   100%) rather than from `target * numerator`, so no intermediate value
   ever exceeds `target` itself. Proven with boundary tests at and near
   `9223372036854775807` (`Money.minorUnits`'s int64 maximum), not only
   ordinary consumer-scale amounts. `Money` itself is NOT changed to
   `BigInt` — the one place `BigInt` is used at all in this feature is
   `SavingsGoalCalculation.wholePercentSaved` (point 7), a transient,
   presentation-only value that never escapes that getter, never stored,
   never fed back into another calculation.

7. **The displayed percentage-saved figure floors, and is never capped
   at 100 while the goal is still unfinished.** `saved / target * 100`
   naively rounded can read "100%" while `saved < target` (e.g. 99.6% →
   rounds to 100), directly contradicting a `status` that's still
   `inProgress` — an internally inconsistent, user-misleading state this
   project does not allow (see ADR-021's identical rule for budgets).
   `SavingsGoalCalculation.wholePercentSaved` instead floors
   (`BigInt`, for exactness near the int64 boundary — see point 6):
   99.6% → 99%, exactly 100% → 100%, an overfunded 142.8% → 142%,
   uncapped above 100. Only a progress bar's *fill fraction* clamps to
   1.0, purely because a bar cannot visually render past full — the text
   next to it never does. Authoritative `Money` throughout this feature
   stays strictly integer-only; this floored percentage is the sole,
   deliberately narrow exception, and even it never leaves `int`.

8. **A soft-deleted goal is unavailable below the UI layer, not merely
   by UI convention.** The original draft's justification for skipping
   this ("`watchActiveForGoal` is only ever called with a live goal id
   from the UI") was rejected during review as too weak — a repository
   invariant must not depend on every future caller behaving correctly.
   Concretely: `SavingsGoalRepository.watchById`/`requireActiveGoal` both
   exclude a soft-deleted row exactly as if it no longer existed (not
   only `watchActiveGoals`, which already did); `SavingsGoalContributionRepository.addContribution`
   requires the parent goal to resolve via `requireActiveGoal` before any
   contribution can be written, so a contribution against a deleted goal
   is rejected with `SavingsGoalNotFoundException`, in the repository,
   independent of whatever the UI already checks; and the presentation
   layer's `goalSummariesProvider`/`goalSummaryProvider` are built
   entirely from `watchActiveGoals`, so a deleted goal's detail screen
   resolves to an explicit "no longer available" state rather than
   continuing to show stale data. Historical contribution rows are
   deliberately NOT cascade-deleted when their parent goal is
   soft-deleted — they remain physically present (e.g. for potential
   future export/history), but every read path above still refuses to
   treat their now-deleted parent as active.

9. **Home's priority-goal selection operates over a derived
   `SavingsGoalSummary` (goal row + calculated `SavingsGoalCalculation`),
   never over a raw `SavingsGoalRow` alone.** The original draft's
   raw-row approach was internally inconsistent — ordering by completion
   status is impossible without the derived `saved` total, which only
   exists after summing that goal's active contributions.
   `goalSummariesProvider` derives every active goal's summary from two
   watched streams (the active-goal-row list, and every active
   contribution across the current active goal set — the latter
   `asyncExpand`s off the former's own stream, cancelling and
   re-subscribing its inner `watchActiveForGoals` query automatically
   whenever the active goal set changes, with no SQL join and no rxdart
   dependency); `selectHomeGoalSummary` is a small, pure,
   non-Riverpod function operating purely over `List<SavingsGoalSummary>`
   (directly unit-testable without a `ProviderContainer`), and
   `homeGoalSelectionProvider` just wraps it around
   `goalSummariesProvider`'s current value.

10. **There is no "most recently completed goal" Home fallback.** A
    goal's completion timestamp is not persisted anywhere in this schema
    (only `created_at`/`updated_at` are), so inferring "most recently
    completed" from either would be a guess dressed up as a fact — this
    was explicitly rejected during review. When every one of the
    profile's goals is completed, the Home card instead shows an
    explicit "All your savings goals are completed." state (with a "View
    all" link to the full list) rather than picking one. When there are
    no goals at all, a separate, distinct empty state with a
    call-to-action is shown. A completed goal never competes with an
    unfinished one for the priority slot.

11. **Home priority order among unfinished goals:** (a) `overdue` before
    `inProgress`; (b) within a status, the sooner target date wins, and a
    goal with no target date sorts after every goal that has one; (c)
    `createdAt` ascending as the final, deterministic tie-breaker. This
    never needs a completion timestamp (point 10) because completed
    goals are filtered out before this ordering is ever applied.

12. **`SavingsGoalCalculator`'s own unit tests stay narrowly scoped to
    calculation, not repository/provider concerns.** Because
    `SavingsGoalCalculator.evaluate` takes an already-summed `Money saved`
    rather than a list of contributions, a case like "a soft-deleted
    contribution must be excluded from the total" is NOT a calculator
    test — that behavior is tested where it actually lives:
    `SavingsGoalContributionRepository`'s own tests (exclusion from
    `watchActiveForGoal`/`watchActiveTotalForGoal`) and the provider
    integration tests (`goalSummariesProvider` reflecting only active
    contributions). The pure calculation tests
    (`test/features/goals/domain/savings_goal_calculation_test.dart`)
    test only what the calculator itself decides: target, a given `saved`
    `Money` input, remaining, status, pace, and milestones.

13. **Contributions are an explicit, append-only ledger with no
    `Transactions` side effect.** `SavingsGoalContributionRepository.addContribution`
    never creates a `transactions` row — a contribution toward a savings
    goal has no income/expense/transfer meaning in this schema. Beta 1's
    UI never backdates a contribution (no date field on the add-
    contribution dialog), but the repository API accepts an optional
    `contributedAt` specifically so its own tests can be deterministic
    (point 3) — this is a repository-level affordance, not a UI feature
    gap being papered over. Beta 1 supports deleting (soft) a
    contribution but not editing one.

14. **No new bottom-nav item; the smallest working Home/Profile
    integration.** Savings Goals is reached from the Profile screen's new
    "Savings Goals" entry and from the Home dashboard's new savings-goals
    card (empty / priority-goal / all-completed states — points 10-11),
    exactly mirroring how Budgets was integrated in Task 2. `/goals` and
    `/goals/:id` are the only two new routes.

Status: Approved 2026-09-03 (Beta 1 Task 3).

## ADR-023 — Beta 1 Task 4A recurring money foundation: schedule-only rules, anchor-based recurrence, and explicit posting

Decision: Beta 1's recurring money foundation (schema version 4) is
built on the following deliberate choices, following the same
schedule/template-vs-real-transaction separation the task's own
specification required.

1. **Two new tables, `recurring_rules` and `recurring_occurrences`,
   added via `onUpgrade`, not `onCreate`.** No existing table changes
   shape and no historical row is touched. A rule is a schedule/template
   only — `RecurringRuleRepository.createRule`/`updateRule` never write
   to `transactions` and never affect an account balance, income/expense
   total, budget, or savings goal; only
   `RecurringOccurrenceRepository.postOccurrence` does that, and only
   when explicitly called (never automatically, in this task).
   `recurring_rules.kind` is permanently fixed at creation — see point 5.
   `recurring_rules` carries the same `deleted_at`/`sync_version`/
   `sync_status` soft-delete convention every other table has carried
   since ADR-020; `recurring_occurrences` deliberately does NOT — it is
   append-only (see point 4), so there is nothing on it to soft-delete.
   A migration test (`test/core/database/recurring_migration_test.dart`)
   builds a v3 database by hand (raw SQL, cross-checked column-for-column
   against `tables.dart`, plus `PRAGMA user_version = 3`), seeds a
   profile/accounts/categories/transactions/budgets/savings-goals/
   contributions, opens it with the real (v4) `AppDatabase`, and asserts
   the new tables exist and are usable and that every v3 row's LOGICAL
   data survives unchanged.

2. **Recurrence is computed anchor-based, never by cascading from the
   previously clamped occurrence.** `RecurringSchedule._occurrenceAt(k)`
   (`lib/features/recurring/domain/recurring_schedule.dart`) always
   derives occurrence `k` directly from the rule's own `startDate` —
   for daily/weekly it's `startDate + k * interval` days/weeks; for
   monthly/yearly it computes the target year/month `k * interval` units
   ahead of the anchor and clamps `startDate`'s day-of-month
   independently against *that* target month's own last day (via
   `_lastDayOfMonth`), never against a previous occurrence's already-
   clamped day. This is what makes a Jan-31 monthly schedule correctly
   produce Jan 31 → Feb 28/29 → Mar 31 → Apr 30 → May 31 forever, instead
   of drifting permanently to the 28th after the first clamp — the
   specific bug anchor-based computation exists to prevent.
   `occurrenceOnOrAfter`/`nextOccurrenceAfter` binary-search the `k`
   index rather than iterating one occurrence at a time, so even a rule
   anchored years in the past resolves "next due date" in
   O(log distance), not O(elapsed occurrences). `occurrencesInRange` is
   the only bulk accessor and always takes an explicit
   `fromUtc`/`toUtc` bound — there is no unbounded "all occurrences"
   function anywhere in this feature, in either the domain layer or the
   providers built on it (point 6).

3. **Calendar-date and instant normalization follow the exact same
   split ADR-022 point 3 established for savings goals, reused verbatim
   for this feature.** `normalizeRecurringDate` (mirroring
   `normalizeCalendarDateToUtc`) never calls `.toUtc()`/`.toLocal()` — it
   reads `.year`/`.month`/`.day` directly and re-wraps them as UTC
   midnight. `startDate`, `endDate`, and every `scheduledDate` are
   calendar dates and always go through it, at every write boundary
   (`RecurringRuleRepository.createRule`/`updateRule`,
   `RecurringOccurrenceRepository.postOccurrence`/`skipOccurrence`).
   `createdAt`/`updatedAt`/`deletedAt`/`handledAt` are genuine instants
   and use `.toUtc()` instead, same as every other table in this schema.

4. **Handled-occurrence uniqueness is an application-layer invariant,
   not a database-enforced one — the same precedent
   `BudgetRepository`/`SavingsGoalRepository` already established.** At
   most one `recurring_occurrences` row exists per (`ruleId`,
   `scheduledDate`) pair, regardless of status. Both `postOccurrence` and
   `skipOccurrence` check for ANY existing row for that pair before
   writing, and re-check inside the `AppDatabase.transaction` block
   immediately before the insert (defensive against a write landing
   between the two checks) — throwing
   `RecurringOccurrenceAlreadyHandledException` rather than creating a
   second row. Posting an already-posted OR already-skipped occurrence
   is rejected; skipping an already-posted OR already-skipped occurrence
   is rejected. There is no "overwrite" path. Occurrences are never
   pre-generated in bulk — `recurring_occurrences` only ever gains a row
   when a specific scheduled date is explicitly posted or skipped;
   "pending" (overdue/due-today/upcoming) items are always derived
   on-the-fly from the rule's schedule plus whichever dates already have
   a handled row (point 6), never materialized ahead of time.

5. **Posting reuses the existing transaction-layer paths exactly — no
   parallel calculation engine.** `RecurringOccurrenceRepository.postOccurrence`
   creates the real ledger row via `TransactionRepository.recordExpense`/
   `recordIncome`/`recordTransfer`, so every existing invariant
   (same-currency transfer enforcement per ADR-019, transfers excluded
   from income/spending totals per `FinanceEngine.incomeExpenseTotals`)
   applies completely unchanged. The occurrence write and the
   transaction write happen inside one `AppDatabase.transaction` block —
   if either fails, both roll back together, so a failed post can never
   leave a `transactions` row with no matching occurrence, or vice
   versa. `recurring_rules.kind` is permanently fixed at creation
   (`RecurringRuleRepository.updateRule` has no `kind` parameter) because
   the account/currency shape expense/income (one account) and transfer
   (source + destination, same currency, source != destination) require
   is different enough that "editing" a rule's kind would really mean
   replacing it with a different rule — this repository doesn't attempt
   to support that implicitly. Editing a rule's schedule/amount/accounts
   affects only future schedule calculations — it never rewrites an
   already-written `recurring_occurrences` or `transactions` row, both
   of which are immutable-once-created, keyed by their own id/
   `scheduledDate`, never re-derived from the rule after the fact.

6. **Pending items are always bounded, never scanned unboundedly.**
   `recurringPendingItemsProvider` derives every overdue/due-today item
   per rule via `RecurringSchedule.occurrencesInRange(fromUtc: rule.startDate,
   toUtc: todayUtc)` (bounded by the schedule's own range accessor, not a
   manual loop) minus whichever scheduled dates already have a handled
   row, plus exactly one `nextOccurrenceAfter(todayUtc)` lookup for the
   single nearest upcoming item — never a scan of the future. Handled
   occurrences across a profile's active rules are derived the same
   `asyncExpand`-off-the-active-rule-stream way ADR-022 point 9
   established for savings-goal contributions (no SQL join, no rxdart),
   re-subscribing automatically whenever the active rule set changes.

7. **A soft-deleted rule is unavailable below the UI layer, the same
   discipline ADR-022 point 8 established for savings goals.**
   `RecurringRuleRepository.watchActiveRules`/`watchById`/
   `requireActiveRule` all exclude a soft-deleted row; `postOccurrence`/
   `skipOccurrence` both resolve the rule via `requireActiveRule`, so
   neither can act on a deleted rule, independent of whatever the UI
   already checks. A deleted rule's already-posted `transactions` rows
   and already-handled `recurring_occurrences` rows are never
   cascade-deleted or otherwise touched — they remain exactly as they
   were, satisfying the task's "historical records preserved after rule
   delete" requirement.

8. **Home's recurring summary shows exactly one item, in its own
   currency, and structurally cannot sum across currencies.**
   `RecurringHomeSelection` carries an optional single
   `RecurringPendingItem` (never a `Money` total field), selected by
   `selectHomeRecurringItem` — a small, pure, non-Riverpod function
   (same precedent as `selectHomeGoalSummary`) that simply takes the
   first entry of `recurringPendingItemsProvider`'s own
   overdue-then-today-then-nearest-upcoming ordering. Because the type
   has no numeric total field at all, there is no code path that could
   accidentally add two different currencies' amounts together — the
   task's "must not sum mixed currencies... do not fabricate a converted
   combined total" requirement is enforced by the shape of the data, not
   by a runtime check that could be bypassed later.

9. **No new bottom-nav item; no OS notifications yet.** `/recurring` is
   the only new route, reached from the Profile screen's new "Recurring"
   entry and the Home dashboard's new recurring summary card (empty /
   single-item states), exactly mirroring how Budgets and Savings Goals
   were integrated in Tasks 2 and 3. Reminder/notification scheduling is
   explicitly out of scope for this task (Task 4B, once the deterministic
   engine here is verified) — nothing in this feature registers a local
   notification or background job.

Status: Approved 2026-09-04 (Beta 1 Task 4A).

## ADR-024 — Beta 1 Task 4B recurring local reminders: opt-in notifications, a scheduler abstraction, and reconciliation-not-a-worker

Decision: local (never remote/push) reminder notifications for recurring
rules are added on top of Task 4A's schedule engine without changing its
math, and without ever letting a notification post a transaction itself.

1. **Schema version 5 adds exactly one column —
   `recurring_rules.notifications_enabled` (bool, default `false`) — via
   `onUpgrade`, not `onCreate`.** Every pre-existing row backfills to
   `false`: nobody is retroactively opted in just because the column now
   exists. `recurring_occurrences` gains nothing — a notification is a
   property of the RULE's preference, not of any one occurrence, and
   Task 4B never needed to record per-occurrence notification state (see
   point 4). `RecurringRuleRepository.createRule`/`updateRule` both grow
   this field additively (`createRule`'s new parameter defaults to
   `false`; `updateRule`'s is a `Value<bool>` sentinel, "leave unchanged"
   when omitted) — every existing call site keeps compiling unchanged. A
   migration test (`test/core/database/
   recurring_notifications_migration_test.dart`) builds a v4 database by
   hand, seeds a rule, opens it with the real (v5) `AppDatabase`, and
   asserts the pre-existing rule reads back with `notificationsEnabled
   == false` and a newly-created rule can set it to `true`.

2. **A `NotificationScheduler` abstraction is the ONLY thing any
   recurring provider/repository/domain file depends on —
   `flutter_local_notifications`/`timezone`/`flutter_timezone` are
   imported by exactly one file, `lib/core/notifications/
   local_notification_scheduler.dart`.**
   `lib/core/notifications/notification_scheduler.dart` declares the
   interface (`schedule`/`cancel`/`pendingIds`/`permissionStatus`/
   `requestPermission`) plus the `ScheduledReminder` value type it
   operates on. `ScheduledReminder` deliberately carries a calendar date
   (`scheduledDateUtc`), never a precise instant or a `TZDateTime` —
   converting "this UTC calendar date" into "09:00 in the device's
   current local timezone, DST-safe" happens entirely inside
   `LocalNotificationScheduler.schedule` via
   `tz.TZDateTime(location, year, month, day, 9)`, whose constructor
   resolves that correctly across a DST transition on its own. This is
   what keeps the pure recurring reminder planner (point 3) and the
   Riverpod reconciliation layer (point 4) free of any timezone-package
   dependency, not just the plugin itself. `notification_providers.dart`
   exposes it as a plain (non-`autoDispose`) `Provider`, overridable with
   an in-memory fake in every test (`test/support/
   fake_notification_scheduler.dart`) — no test in this feature needs a
   real device.

3. **A pure `recurring_reminder_planner.dart` decides WHICH dates want a
   reminder; it has no I/O, no plugin awareness, and no platform-id
   concept.** `planDesiredReminders` takes active rules (as a small
   `RecurringReminderRuleInput` — deliberately not a `RecurringRuleRow`,
   same Drift-independence `RecurringSchedule` itself already has),
   already-handled occurrence keys, "now", and a horizon, and returns
   every `DesiredReminder` (rule + calendar date + plain content fields).
   For each rule with `notificationsEnabled == true`, it includes every
   occurrence from today (inclusive) through a **fixed 14-day horizon**
   — long enough that even a monthly/yearly rule's reminder is always
   scheduled well before it's due, short enough that reconciling on
   lifecycle events (point 4) rather than a background worker never
   meaningfully falls behind, bounding the OS-level pending-notification
   count to `activeRules.length * 14`. It deliberately EXCLUDES anything
   strictly before today ("overdue") — that backlog is already surfaced
   in-app by `recurringPendingItemsProvider`; a local reminder is for
   something not yet due, not a second nag about something the Overdue
   list already shows. Both **posted and skipped** occurrences remove a
   date from the desired set equally (`HandledOccurrenceKey` carries no
   status) — the user has dealt with it either way, so neither should
   still ring.

4. **Notification-id collisions are resolved explicitly, never trusted
   to a bare hash.** `NotificationIdAllocator`
   (`lib/core/notifications/notification_id_allocator.dart`) computes an
   FNV-1a-based base id per `(ruleId, scheduledDateUtc)`, but a single
   `allocate()` call first sorts every key (so the outcome never depends
   on caller iteration order — the same desired set always allocates the
   same ids) and then, walking that sorted order, linearly probes
   forward past any id already claimed earlier in the same pass. Every
   key handed to one `allocate()` call is therefore GUARANTEED a distinct
   id, not merely "usually" one. Kept as its own class, entirely outside
   `RecurringSchedule` and the planner — id allocation is a
   notification-scheduling/platform-boundary concern, never recurrence
   mathematics. Its base-id function is injectable specifically so a
   test (`test/core/notifications/notification_id_allocator_test.dart`)
   can force real collisions deterministically rather than hoping to
   find two strings that happen to hash the same.

5. **Reconciliation is one algorithm, re-run in full on four triggers,
   never a background worker.** `reconcileRecurringReminders`
   (`lib/features/recurring/presentation/
   recurring_notification_providers.dart`) computes the full desired set
   (point 3), allocates ids (point 4), calls `scheduler.schedule` for
   EVERY desired reminder unconditionally, then cancels every currently-
   pending id `scheduler.pendingIds()` reports that is no longer
   desired. Re-scheduling the full set every pass — rather than diffing
   content itself — is what makes every one of the following fall out of
   ONE algorithm rather than needing separate cases: editing a rule's
   schedule (stale dates drop out of the desired set and get cancelled;
   new dates get scheduled), editing only name/amount (the id is
   unchanged, so re-scheduling it just replaces its content in place, no
   duplicate), posting/skipping an occurrence (that date leaves the
   desired set on the very next pass), soft-deleting a rule (it leaves
   `activeRules` entirely, so none of its dates are ever desired again),
   and repeated reconciliation with nothing changed (the same desired
   set always allocates the same ids, and re-scheduling an unchanged
   reminder under its existing id is a no-op at the OS level — never a
   duplicate). `recurringNotificationReconcilerProvider` triggers this on
   THREE of the task's four required triggers purely through Riverpod's
   own dependency graph (cold start; `activeRecurringRulesProvider`
   changes; `handledOccurrencesProvider` changes — the latter renamed
   from `_handledOccurrencesProvider`, made public, specifically so this
   file could watch it without re-implementing the same Drift query).
   The fourth — app foreground/resume — cannot come from a data change
   (the 14-day horizon advances with wall-clock time alone), so
   `AiFinancialCoachApp` (now a `ConsumerStatefulWidget` +
   `WidgetsBindingObserver`, the minimal shape change needed for this one
   hook) calls `ref.invalidate(recurringNotificationReconcilerProvider)`
   on `AppLifecycleState.resumed`, forcing a fresh pass against a new
   `DateTime.now()`. No background worker/isolate exists anywhere in this
   feature — Beta 1 deliberately scopes that out; these four triggers are
   judged sufficient to never meaningfully fall behind.

6. **Notification permission is requested ONLY as the direct,
   synchronous result of the user enabling one rule's "Remind me"
   toggle — never at startup, during reconciliation, or from an
   unrelated rebuild.** `_RuleDialog`'s new `SwitchListTile` calls
   `NotificationScheduler.requestPermission()` from its `onChanged`
   handler when (and only when) the user turns it ON; turning it off
   never touches permission at all.
   `reconcileRecurringReminders`/`recurringNotificationReconcilerProvider`
   never call `requestPermission` — only `schedule`/`cancel`/
   `pendingIds` — so opening the Recurring screen, an unrelated Riverpod
   rebuild, or cold start can never trigger an OS prompt. If permission
   isn't granted, the toggle reverts to `false` (persisted state should
   reflect actually-usable behavior, not a wish) and a concise one-line
   `SnackBar` explains it — no crash, no repeated automatic prompt (the
   handler only asks again if the user taps the switch again
   themselves), and every other recurring/financial function keeps
   working normally regardless of the answer.

7. **Notification content is concise, per-rule, and never fabricates a
   total or a conversion.** `buildRecurringReminderContent`
   (`lib/core/notifications/recurring_reminder_content.dart`) renders
   exactly one `DesiredReminder`'s own rule name, income/expense/transfer
   label, and `MoneyFormatter`-rendered amount in ITS OWN currency —
   never a `double`, never a sum across rules, never a cross-currency
   figure. Pure and plugin-free, directly unit-tested
   (`test/core/notifications/recurring_reminder_content_test.dart`)
   without a device.

8. **Package choice and native configuration were deliberately kept out
   of this task's Beta 1 code where they could not be verified.**
   `flutter_local_notifications` (+ `timezone`, + the minimal
   `flutter_timezone` purely for the device's IANA name, per this task's
   own scope) were chosen after inspecting the existing `pubspec.yaml`/
   `pubspec.lock` and looking up each package's current pub.dev listing
   — no `permission_handler` (this task needs no permission this plugin
   doesn't already expose). `LocalNotificationScheduler` is written
   against those packages' documented public API as fetched at
   implementation time, with an explicit doc-comment warning to verify
   it against whatever version `flutter pub get` actually resolves
   locally, since no Flutter toolchain was available to compile-check it
   directly. Android manifest/Gradle changes and any iOS `AppDelegate`
   changes are deliberately NOT made in this pass — they are the next,
   separate step once the developer has actually run `flutter pub get`
   locally and can inspect the real installed version's real
   requirements, rather than copying setup instructions from memory or
   from a version that may not be what gets resolved.

Status: Approved 2026-09-05 (Beta 1 Task 4B).

## ADR-025 — Checkpoint 9.3: persistent reference-rate cache is schema v7, and is architecturally separate from historical FX snapshots

Decision: schema version 7 adds exactly one new table,
`reference_exchange_rates` (see `03_DATABASE_SCHEMA.md`), to hold the
CURRENT/reference FX-rate cache introduced in Checkpoint 9.2
(`ReferenceFxRate`/`ReferenceFxRateCache`/`ReferenceFxRateService`).
Checkpoint 9.2 shipped only an in-memory implementation of that cache
(restart-volatile); this migration is what lets `DriftReferenceFxRateCache`
persist it.

1. `reference_exchange_rates` is a brand-new table, not a reuse of
   `transaction_exchange_rates`. The two are deliberately independent and
   must never be confused: `transaction_exchange_rates` is ADR-009/
   ADR-010's immutable historical snapshot, permanently attached to one
   transaction, never replaced. `reference_exchange_rates` is a
   replaceable, freshness-based CURRENT market quote (ADR-011: "FX rates
   are reference data") with no connection to any transaction, account,
   budget, or goal. Nothing in this migration reads, rewrites, or deletes
   a row of the historical table.
2. Its primary key is the composite `(base_currency, quote_currency)`
   pair — the only table in this schema to use a composite key instead of
   a surrogate `id` — because a cache row's identity genuinely IS the
   ordered currency pair, nothing else in the schema references it by id,
   and the cache's own contract requires "at most one row per ordered
   pair" with deterministic replace-on-conflict (upsert) behavior, which
   the composite key enforces at the database level rather than the
   application layer. `(USD, JPY)` and `(JPY, USD)` remain independent
   rows.
3. `rate` is stored as TEXT (a plain decimal string), never REAL/`double`
   — identical reasoning to `transaction_exchange_rates.rate` (ADR-018).
4. This reconciles `03_DATABASE_SCHEMA.md`'s original aspirational
   `exchange_rates`/`user_currency_pairs`/`rate_alerts` blueprint section:
   `reference_exchange_rates` is what actually shipped for the first of
   those three, under a different name and a different key strategy than
   originally sketched (see that doc's own updated note); a favorites
   table (`user_currency_pairs`) and rate alerts remain unimplemented and
   out of this checkpoint's scope.
5. This checkpoint is database-only: no real `FxRateProvider` vendor
   integration, no FX UI, and no automatic/background refresh were added.
   `InMemoryReferenceFxRateCache` was kept (not deleted) for tests; normal
   application code now receives `DriftReferenceFxRateCache` via
   `referenceFxRateCacheProvider`.

Reason: a real persistent cache needs real storage, and this is the
narrowest schema change that provides it without touching any existing
table's shape or any financial data, and without conflating "current
market quote" with "historical transaction fact" — the exact distinction
ADR-009/ADR-010/ADR-011 already established and this checkpoint is
required to preserve.

Status: Approved 2026-09-18 (Checkpoint 9.3).

## ADR-026 — Checkpoint 9.4: real reference-rate provider is ExchangeRate-API's Open Access endpoint, ingested via a raw-text exact-decimal boundary, no API key

Decision: `FxRateProvider`'s first real (non-fake) implementation,
`ExchangeRateApiFxRateProvider` (`lib/core/fx/`), calls
ExchangeRate-API's "Open Access" endpoint
(`https://open.er-api.com/v6/latest/{BASE}`,
https://www.exchangerate-api.com/docs/free) directly over `dart:io`'s
built-in `HttpClient`, behind a new minimal `HttpTransport` seam
(`lib/core/network/http_transport.dart`).

1. **Vendor selection.** Evaluated against Beta 0's full
   `CurrencyRegistry` seed set (JPY, KRW, VND, KWD, MMK, LKR, NPR, INR,
   BDT, QAR, CAD, EUR, USD):
   - Frankfurter (frankfurter.dev) was rejected: as of this checkpoint
     it still sources exclusively from the ECB's ~31-currency reference
     set, and VND/KWD/MMK/LKR/NPR/BDT/QAR are tracked as *unimplemented*
     currency requests in its own issue tracker (lineofflight/frankfurter
     issues #144/#169) — more than half of this registry would be
     unsupported.
   - Open Exchange Rates and Fixer were rejected for V1: their free
     tiers restrict the request to a *fixed* base currency (USD or EUR
     respectively) — `FxRateProvider.fetchRates`'s contract takes an
     arbitrary `baseCurrencyCode`, and answering an arbitrary base from
     a fixed-base free tier would require triangulating through a
     hidden second currency inside the adapter, which is exactly the
     kind of implicit cross-rate computation this checkpoint's "no
     automatic inversion" / "no hidden fallback provider" rules exist to
     prevent.
   - ExchangeRate-API's Open Access endpoint supports every one of the
     13 registry currencies, accepts an arbitrary requested base with no
     API key, is HTTPS, versioned (`/v6/`), documented, states its data
     is daily reference/indicative (never an executable/bank/remittance
     rate — matching ADR-011 exactly), and permits personal *and*
     commercial caching/use subject to attribution and a
     no-redistribution term. It was selected on this basis.
2. **No API key, so no secret-handling machinery was built.** This
   endpoint requires no credential at all — there is nothing to keep out
   of source control, tests, or Git history, and CP9.4's configuration-
   boundary/"mobile key isn't truly secret" concerns are moot for this
   specific vendor. If a future checkpoint adds a key-requiring provider
   (a paid tier, a different vendor, a backend proxy), the seam to change
   is `fxRateProviderProvider`/`ExchangeRateApiFxRateProvider`'s
   constructor — nothing about `FxRateProvider`, `ReferenceFxRateService`,
   or `ReferenceFxRateCache` would need to change.
3. **Exact-decimal ingestion never goes through `double`.** This
   provider's JSON response encodes each rate as a bare JSON number
   literal (e.g. `"JPY": 149.85`), not a quoted string — decoding that
   through `dart:convert`'s standard `jsonDecode` would materialize it as
   a `double`, exactly the "authoritative binary floating point" ADR-017/
   ADR-018 already forbid anywhere near money or an `FxRate`.
   `ExchangeRateApiFxRateProvider` never does this: `jsonDecode` is used
   only to validate response *shape* (object structure, `result`,
   `base_code`, which keys `rates` contains) — the actual rate value for
   the requested quote currency is re-extracted from the **raw response
   text** via a brace-depth- and string-literal-aware scan scoped to the
   `rates` object, and that literal string is handed directly to
   `FxRate`'s own constructor, unchanged. A malformed/non-numeric/
   exponent-notation/excess-precision/non-positive token for one
   requested quote is dropped for that quote only (never accepted, never
   crashes the whole request) — see `FxRateProvider`'s own "partial
   response is valid" contract, unchanged by this checkpoint.
4. **No new pubspec dependency.** This project targets Android/iOS only
   (ADR-001; nothing here targets Flutter Web — Drift is wired through
   `NativeDatabase`, a native-only implementation). `dart:io.HttpClient`
   is a Flutter/Dart SDK built-in on those platforms, so
   `IoHttpTransport` needed no `package:http`/`dio`/etc. addition and no
   separate dependency-approval step.
5. **No policy duplicated in the adapter.** `ExchangeRateApiFxRateProvider`
   answers exactly one question — "what did the vendor say for this pair,
   right now" — as a `FxRateProviderSuccess`/`FxRateProviderFailure`. All
   fresh/stale/unavailable-fallback decision-making remains exclusively
   `ReferenceFxRateService`'s job, unchanged since CP9.2/CP9.3. No
   retries, no background polling, no automatic pair inversion.
6. **`ReferenceFxRate.observedAt` semantics for this vendor.**
   ExchangeRate-API's `time_last_update_unix` (a bare JSON *integer* —
   safe to decode via `jsonDecode`/Dart `int`, unlike the rate values) is
   used as `observedAt` when present and non-negative. When absent or
   malformed, `observedAt` is set equal to `fetchedAt` (the actual UTC
   retrieval instant) rather than inventing historical precision the
   response didn't actually provide.
7. **Still no FX UI, no cross-currency transfers, no accounting
   integration, no automatic/background refresh, no attached-to-a-
   transaction usage of any kind.** `ReferenceFxRateService` remains
   directly constructible but is still not wired as a Riverpod provider
   (no consumer exists yet) — only `httpTransportProvider` and
   `fxRateProviderProvider` (the new provider-layer DI, paired with
   CP9.3's existing `referenceFxRateCacheProvider`) were added.

Reason: V1 needs one small, legally-usable, sufficiently-covering vendor
integration behind the existing `FxRateProvider` abstraction, without
adding a dependency, without ever letting binary floating point touch an
exchange rate, and without smuggling caching/staleness policy into the
vendor-specific layer that CP9.2's architecture deliberately keeps
ignorant of it.

## ADR-027 — Checkpoint 9.5: Reference Rate is a presentation-only V1 surface — fixed home→living direction, per-currency-card Home equivalents, no schema/dependency change

Context: Checkpoints 9.1–9.4 built the entire reference-FX engine (`FxRate`,
`FxConverter`, `ReferenceFxRateService`, `ReferenceFxRateCache`, a real
network provider) with no consumer at all — by design, so no UI-facing
policy would be invented ahead of an actual screen needing it. Checkpoint
9.5 is that first consumer: a small "Reference Rate" card in International
Preferences, and a quiet Home/Living equivalent line on the Home
dashboard's per-currency cards. Three product/architecture decisions were
made that are genuinely worth recording (not routine implementation
detail):

1. **`ReferenceFxRateService` is now wired as a Riverpod provider, with a
   record-keyed family for a specific ordered pair.**
   `referenceFxRateServiceProvider` (plain `Provider`, app-lifetime,
   mirrors `referenceFxRateCacheProvider`) constructs the service from
   the existing `fxRateProviderProvider`/`referenceFxRateCacheProvider`.
   `referenceRateProvider` is `FutureProvider.autoDispose.family` keyed
   by a `(String base, String quote)` record — chosen over a bespoke key
   class purely because Dart records already give correct value
   equality, the same "record as key" idiom `FxConverter._decompose`
   already uses for an unrelated purpose. `.autoDispose` because a
   specific pair's resolved future is screen-scoped (no reason to keep
   it alive once nothing on screen is watching it); the persistent cache
   underneath is what actually avoids redundant network calls across
   dispose/recreate cycles, not this provider's own lifetime.
2. **The Reference Rate settings card always requests
   `homeCurrency -> livingCurrency`, never the inverse, and this
   direction is a fixed product choice, not a user-facing control.**
   International Preferences already frames both currencies from a
   consistent "home vs. living" perspective (see its own field labels);
   showing "1 [home] = [rate] [living]" reads naturally in that same
   frame ("what is my home currency worth here"). Building a
   direction-swap control was explicitly out of this checkpoint's speed/
   scope rule ("do not expand into a converter screen").
3. **The Home/Living equivalent (Task F) never needed a mixed-currency
   aggregate, and therefore never triggered its own STOP condition.**
   `dashboardCurrencySummariesProvider` was already, by design since
   ADR-017, a per-currency LIST rather than a single combined figure —
   each `CurrencyDashboardSummary` is already a deterministic,
   single-currency amount. The Home/Living equivalent converts each such
   card's own balance individually (one `FxConverter.convert` call per
   card, `sourceCurrency = that card's currency`, `target =
   livingCurrency`) and renders the result as an additional, visually
   quieter second figure beside that card's still-authoritative balance
   — it never sums balances across cards or currencies. Scoped
   deliberately to the balance figure alone (not income/expense/daily-
   pace) to keep this a small V1 addition rather than three more
   equivalent lines per card.
4. **No schema migration, no new dependency.** `reference_exchange_rates`
   (schema v7, CP9.3) is read/written exactly as before — CP9.5 adds no
   column and no table. No package was added; the new UI is built
   entirely from existing shared widgets (`AppCard`/`AppSectionHeader`/
   `AppStatusChip`) and a small new pure-Dart formatter
   (`ReferenceFxRateFormatter`) that never touches `double`, mirroring
   (but never reusing, since an FX rate is not a `Money`)
   `MoneyFormatter`'s own grouping approach.

Reason: a V1 "make the existing FX engine visible" checkpoint should add
exactly one, deterministic, well-justified answer to "which direction" and
"which aggregate" rather than leaving either as an implicit per-screen
choice, while changing nothing about accounting truth, schema, or
dependencies.

Status: Approved 2026-09-18 (Checkpoint 9.5).

## ADR-028 — Checkpoint 9.6: Currency Converter is presentation-only on the existing FX engine — session-only favorites, no schema/dependency change

Context: Checkpoint 9.6 adds a user-facing Currency Converter and a
lightweight favorite-currency-pairs feature, entirely on top of the
CP9.1–CP9.5 FX engine (`FxRate`, `FxConverter`, `ReferenceFxRateService`,
`referenceRateProvider`, `ReferenceRateView`, `ReferenceFxRateFormatter`).
No new conversion, formatting, or freshness/caching logic was written —
every number on this screen is produced by calling that existing engine
exactly the way `ReferenceRateCard`/Home's `_LivingCurrencyEquivalentLine`
already do. Several decisions were genuinely worth recording:

1. **Favorite currency pairs are SESSION-ONLY presentation state in V1,
   not durably persisted, and this is intentional.** The audit found no
   schema-migration-free, dependency-free way to persist them: `profiles`
   has no generic key-value/JSON column to repurpose, and no
   `shared_preferences`-equivalent package exists in `pubspec.yaml`.
   CP9.6's own explicit boundary forbids adding either "merely for this
   feature," so favorites persistence STOPped per that boundary and is
   implemented instead as a plain in-memory
   `favoriteCurrencyPairsProvider` (`StateProvider<List<(String,
   String)>>` — see `lib/features/settings/presentation/
   favorite_currency_pairs_provider.dart`) that resets on every app
   restart. The screen says so explicitly
   (`favoritePairsSessionNote`) rather than letting a user believe a
   starred pair survives a restart. A durable `favorite_currency_pairs`
   table (a genuine, additive schema v7 -> v8 migration, same shape as
   CP9.3's `reference_exchange_rates` addition) is the natural follow-up
   whenever favorites durability is prioritized as its own checkpoint.
2. **A currency-pair swap always issues a new ordered-pair request —
   never a client-side reciprocal.** Swapping From/To only changes which
   `(base, quote)` record key `_ReferenceRateStatus`/`_ConversionResult`
   watch on `referenceRateProvider`; `ReferenceFxRateService` resolves
   `to -> from` on its own terms (cache first, then provider) exactly
   like any other pair request. No `1 / rate` inversion is computed
   anywhere in `currency_converter_screen.dart`. The typed amount is
   deliberately left as-is across a swap (not replaced by the prior
   converted result) — `MoneyTextField`'s existing `didUpdateWidget`
   re-validation (already shipped, unmodified by this checkpoint) simply
   reinterprets the same digits under the newly-selected From currency's
   own minor-unit precision, the same behavior every other currency-aware
   amount field in this app already has when its currency changes.
3. **Amount changes never trigger a new FX request.** The
   `referenceRateProvider` watch is keyed by `(fromCurrency,
   toCurrency)` alone; the typed amount is not part of that key and only
   ever drives local `FxConverter.convert` arithmetic on top of whatever
   rate is already resolved. Riverpod's own family-provider caching means
   re-watching the same key on every keystroke's rebuild never re-invokes
   the provider function — no debounce/throttle logic was written or
   needed to satisfy this.
4. **No schema migration, no new dependency.** `reference_exchange_rates`
   (schema v7) and every other table are read/written exactly as before;
   this checkpoint adds no column and no table. No package was added —
   the screen is built entirely from existing shared widgets
   (`AppCard`/`AppSectionHeader`/`AppStatusChip`/`MoneyTextField`) and the
   existing FX/money engine.
5. **The converter remains strictly informational.** It never creates a
   `Transactions` row, never touches an account balance/budget/goal/
   income/expense figure, never writes `transaction_exchange_rates`
   (CP9.1's immutable historical-snapshot table stays architecturally
   untouched, exactly as `ReferenceExchangeRates`'s own doc comment
   requires), and cross-currency transfers remain rejected exactly as
   before — this checkpoint adds no new path around that rule.

Reason: a V1 converter should expose the existing, already-correct FX
engine to the user with no new conversion/rounding/caching logic of its
own, and a feature whose only safe persistence options are "add a
migration" or "add a dependency" should say so plainly and ship as
session-only rather than pretend a lighter option existed.

Status: Approved 2026-09-19 (Checkpoint 9.6).

Status: Approved 2026-09-18 (Checkpoint 9.4).

## ADR-029 — Checkpoint 9.7: V1 FX is hardened and frozen; Receipt OCR moves to V2

Context: Checkpoint 9.7 was explicitly a closeout pass, not an expansion
checkpoint — verify the existing CP9.1–CP9.6 FX stack (`FxRate`/
`FxConverter` exact deterministic engine, `ReferenceFxRateService` +
`DriftReferenceFxRateCache` reference-rate infrastructure,
`ExchangeRateApiFxRateProvider`, Home/Reference-Rate-card/Currency-Converter
presentation, and session favorite pairs), fix only genuine gaps, and then
freeze FX for V1. Product scope was also narrowed in the same checkpoint:
Receipt OCR is removed from V1 and becomes the first item of V2.

The audit read every production file under `lib/core/fx/`,
`lib/core/network/`, `lib/core/money/`, `lib/core/currency/`, the FX-facing
parts of `lib/features/dashboard/` and `lib/features/settings/`, and every
corresponding existing test, against the seventeen-task checklist (offline/
provider-failure determinism; exact provider ingestion; the full Money
precision matrix; signed-64-bit overflow safety; rate direction/no
inversion; Drift cache hardening; network request discipline; presentation
failure safety; freshness-boundary determinism; historical-FX
non-regression; security/privacy sanity). Every one of those requirements
was found to already be correctly implemented and already covered by
existing tests, with two narrow exceptions — both pure test-coverage gaps,
with **zero production defects and zero production changes**:

1. **Provider ingestion edge cases** (`exchangerate_api_fx_rate_provider_test.dart`,
   6 new groups): a non-object `"rates"` field, a boolean rate value, a
   nested-object rate value, an unrelated string field containing a stray
   `}`, escaped quotes/braces inside a string, and whitespace around a
   rate token. Hand-tracing `_extractRawRateToken`/`_matchingBraceIndex`
   against each case confirmed the existing brace-depth-and-string-aware
   scanner and the trailing-lookahead regex already reject or skip every
   one of these correctly (no partial exponent-notation acceptance, no
   double-based coercion, one malformed quote never poisons the rest of
   the batch) — these tests document and lock in behavior the production
   code already had.
2. **FxConverter boundary cases** (`fx_converter_test.dart`, 4 new tests
   added to the existing "large values near the signed 64-bit boundary"
   group): a conversion whose BigInt intermediate vastly exceeds int64
   magnitude but whose final rounded result is valid (a maxInt64 USD ->
   EUR conversion at a 12-nines rate), the exact positive and negative
   int64 boundaries landing precisely as valid results, and an overflow
   rejected by the smallest margin the 12-fraction-digit rate precision
   cap can produce. All four expected values were hand-derived with exact
   integer arithmetic and independently cross-checked with a standalone
   script mirroring `_roundHalfUpAwayFromZero`/`_requireFitsInInt64`
   before being written, per this project's standing rule against
   asserting "whatever the code currently returns."

No schema change, no new/removed dependency, and no `lib/` production file
was touched. KRW was deliberately not given its own dedicated FxConverter
test: it shares the identical `minorUnits == 0` code path already
exhaustively proven by the existing JPY and VND cases (identity conversion
plus both ROUND HALF UP boundaries), so a KRW-specific duplicate would have
only inflated the suite without proving anything new.

V1 FX is hereby defined as closed and frozen at exactly this surface:
deterministic exact conversion (`FxRate`/`FxConverter`); current/reference
rates via `ReferenceFxRateService`; a persistent Drift reference-rate
cache, isolated from the immutable historical `transaction_exchange_rates`
snapshot table; retrieval from a single open, keyless
ExchangeRate-API-compatible provider with source/timestamp/staleness
tracking; Home living-currency equivalents; the Currency Converter screen;
and session-only favorite currency pairs (ADR-028). Explicitly deferred
beyond V1, and not to be added without a new checkpoint: durable favorite
persistence; rate history/charts; alerts; background refresh/polling;
multiple FX providers or provider selection; remittance comparison;
bank-specific rates; trading features; cross-currency transfers; automatic
transaction FX conversion; FX gain/loss accounting. Receipt OCR is likewise
deferred, but as a product-scope decision rather than an FX one — it is now
the first planned item of V2 and was never part of this checkpoint's file
set.

Reason: a V1 release needs one point where FX is declared "done" rather
than perpetually extensible, and the correct way to reach that point after
five prior FX checkpoints is to verify exhaustively, close only
demonstrated test gaps, and explicitly write down what is deferred —
not to keep adding FX surface area on the strength of momentum.

Status: Approved 2026-09-19 (Checkpoint 9.7). Pending Windows verification
(`flutter analyze`; `flutter test test/core/fx/`; `flutter test
test/core/network/`; `flutter test
test/features/settings/presentation/currency_converter_screen_test.dart`;
`flutter test
test/features/settings/presentation/reference_rate_card_test.dart`;
`flutter test test/widget/home_screen_test.dart`; full `flutter test`) —
this sandbox has no Dart/Flutter toolchain and cannot itself execute or
confirm test results.

## ADR-030 — Checkpoint 10: V1 icon-led UI foundation, evolved from CP7/CP8, not duplicated

Context: an 8-screen finance-app reference image (Home, Accounts, Add
Transaction, Subscriptions, Budgets, Assets & Liabilities, Credit Card,
Family Wallet) was supplied as the primary visual reference for a design
convergence checkpoint. The reference is visual inspiration and a source
of truth for surface treatment, density, and icon-led interaction — it is
explicitly **not** a product-scope document. Nothing visible only in the
mockups (Family Wallet, crypto/property/advanced-asset tracking,
statements, household functionality, OCR, AI, cloud/sync, a donut progress
ring, or a change to primary navigation architecture) was implemented on
the strength of appearing in the image; each remains out of scope until a
future checkpoint explicitly authorizes it.

The Light theme is the primary baseline the reference was calibrated
against (near-white background, a subtle low-alpha blue/lavender ambient
wash confined to the top of the scroll, white rounded cards with soft
restrained shadows, small tinted rounded-square icon containers, compact
list rows, pill single-select segments, thin linear progress, one
dominant hero balance figure). Dark/Pink/Ocean/Forest are true adaptations
of that same language rather than independent skins: they personalize
accent/selected-state/decorative-highlight/gradient/icon-container
treatment only, never by flooding whole surfaces with theme color, and the
income/positive, expense/negative, warning, and (new this checkpoint)
info semantics stay 4-way distinct on every theme (`Phase 6.2` in
`theme_compatibility_test.dart`).

The CP7.1–CP8.1 design-system audit found the foundation already mature
enough that no second, parallel design system was justified. Existing
primitives were evolved in place rather than duplicated: `AppTokens`
gained `AppRadii.xl`, a new `AppIconSizes` class, and new `info`/
`ambientGradient` fields on `AppSemanticColors` (both required, both
derived from the existing `ColorScheme` in `fromColorScheme` — no new
independent color source); `AppTypography` gained `heroMoney` sitting
above the existing `largeMoney`; `AppCard` gained an opt-in `softShadow`
bool (default `false`, so every pre-existing call site is pixel-identical
unless it explicitly opts in); `AppMoneyText`'s `.hero` emphasis was
repointed from `largeMoney` to the new `heroMoney` (confirmed via grep to
be the app's only `.hero` call site — Home's balance figure); and
`TransactionIconBadge`'s hand-rolled tinted `Container`/`BoxDecoration`/
`Icon` was generalized into a call to the new shared `AppIconTile`,
proven a pure rename by asserting the new primitive's medium tier
reproduces the exact pre-existing 40px-container/12px-radius/20px-glyph/
0.14-alpha shape.

Five genuinely missing reusable primitives were added, each because the
audit found no existing equivalent to evolve: `AppIconTile` (a
size-tiered — small/medium/large — tinted rounded-square icon container,
generalizing the badge idiom above beyond transactions), `AppFinanceListRow`
(icon-tile + title/subtitle + trailing amount, for any future finance list
that wants the reference's row shape), `AppSegmentedControl<T>` (a
pill-track single-select control — a genuinely new shape; the audit found
no existing segmented-control pattern anywhere in the app to generalize
from), `AppProgressBar` (a thin rounded `LinearProgressIndicator` wrapper
taking an explicit semantic color, deliberately not the reference's
Budgets donut ring, which this checkpoint's spec text scoped out), and
`AppFilterChip` (a thin `FilterChip` wrapper so filter surfaces pick up
the app-wide chip theme through one call site instead of each screen
calling `FilterChip` directly).

Integration this checkpoint was deliberately partial, proving the
foundation without a screen-by-screen redesign: `AppShell`'s bottom nav
gained a top hairline border from `AppTokens.colors.subtleBorder`; Home
gained the ambient-gradient wash behind its existing content (a
`Positioned` layer added *behind* the untouched `profileAsync.when(...)`
subtree, so every existing widget/key/text below is unaffected) and its
hero balance now renders at `heroMoney`; `_MetricTile`'s bare icon and
`TransactionIconBadge` both now route through `AppIconTile`; Activity's
type filter and Goal Detail's progress bar now route through
`AppFilterChip`/`AppProgressBar` respectively. `AppFinanceListRow` and
`AppSegmentedControl` were built and independently tested this checkpoint
but deliberately left unwired: Home's only existing "list" is a single
recurring-item summary with a delicate, test-asserted width-adaptive
stacked/side-by-side layout that a generic row would regress, and every
existing segmented-looking surface in the app (Categories' `TabBar`,
Add Transaction's modal type picker) would need a behavior/navigation
change, not a pure visual swap, to adopt the new control — out of bounds
for a visual-foundation checkpoint that must not touch navigation
architecture or business logic.

No Drift schema migration, no new or removed dependency, and no FX/
network/OCR/AI/cloud change. The untracked design references under
`docs/design/` were not touched.

Reason: the reference image's job is to calibrate an existing, evolving
component system — radius, spacing, icon-container treatment, surface
tint, typography hierarchy — not to hand the team a new feature list or a
second design system to maintain alongside CP7/CP8's. Building the
missing primitives standalone-and-tested first, then integrating only
where the existing tests already prove it's safe, keeps this checkpoint a
foundation checkpoint rather than an undisclosed screen-by-screen
redesign.

Status: Approved 2026-09-19 (Checkpoint 10). Pending Windows verification
(`flutter analyze`; `flutter test test/widget/shared/`; `flutter test
test/widget/theme_compatibility_test.dart`; `flutter test
test/widget/home_screen_test.dart`; `flutter test
test/widget/activity_screen_test.dart`; `flutter test
test/widget/goal_detail_screen_test.dart`; `flutter test
test/widget/app_shell_test.dart`; full `flutter test`) — this sandbox has
no Dart/Flutter toolchain and cannot itself execute or confirm test
results.

## ADR-031 — Checkpoint 11: Subscriptions V1 is a view over the existing recurring engine, with deterministic, currency-separated estimated totals

Context: Checkpoint 11 asked for a V1 "Recurring + Subscriptions"
experience that reuses the existing recurring money engine and the CP10
icon-led visual system, explicitly forbidding a second accounting engine
for subscriptions, a schema migration unless the existing recurring
model genuinely cannot represent the minimum V1 distinction, a fifth
bottom-nav destination, and any fabricated or live-FX-derived combined
total across currencies.

**Subscription modeling: no new field, no migration.** A "subscription"
is defined purely as an active (non-deleted), `RecurringRuleKind.expense`
recurring rule — see `subscription_providers.dart`'s `isSubscriptionRule`.
This required zero changes to `RecurringRules`/`RecurringOccurrences`
(`lib/core/database/tables.dart`) and zero changes to
`RecurringRuleRepository`/`RecurringOccurrenceRepository`. The
alternative considered — a new boolean/tag column distinguishing
"subscription" from other recurring expenses (e.g. so a user could
exclude rent from a Subscriptions view) — was rejected for V1: every
piece of data the brief asks V1 to present (name, amount, currency,
frequency, next occurrence, source account, active/upcoming status,
estimated totals) is already fully derivable from the existing
`RecurringRuleRow` shape, so a schema change would add a persisted
column with no V1 behavior that actually needs it. This is exactly the
checkpoint's own "prefer the existing recurring model" default rather
than the "STOP and explain" migration path — recorded here as that
explanation. Deferred to V2: an explicit opt-out/tag so a user can
exclude a specific expense-kind rule (e.g. rent) from the Subscriptions
view without it ceasing to be a normal recurring expense on the
Recurring tab.

**Presentation, not a second engine.** `subscription_providers.dart`
adds exactly two providers, both pure derivations of data
`recurring_providers.dart` already computes reactively:
`subscriptionPendingItemsProvider` filters/dedupes
`recurringPendingItemsProvider`'s own already-sorted list down to one
row per subscription rule (`selectSubscriptionPendingItems`, a pure,
directly unit-tested selector — same precedent `selectHomeRecurringItem`
established), and `subscriptionEstimatedTotalsProvider` folds
`activeRecurringRulesProvider`'s rules into per-currency totals
(`computeSubscriptionEstimatedTotals`). Neither provider writes
anything, introduces a new notion of "handled", or duplicates
`RecurringSchedule`'s occurrence math — both call the now-public
`recurringScheduleOf` (renamed from a private `_scheduleOf` this
checkpoint, purely so this second call site can reuse it rather than
re-deriving the same four-field mapping). The Recurring tab's existing
`_PendingItemTile` widget is reused verbatim for Subscriptions rows —
only a generic leading icon and an optional resolved account name
differ — so there is exactly one row implementation to keep correct.

**Deterministic estimated totals, never a fabricated exact figure.**
`RecurringEstimate` (`lib/features/recurring/domain/recurring_estimate.dart`)
computes a rule's average monthly and yearly cost under an explicit,
documented convention — a 365-day year, a 12-month year — using exact
integer/rational arithmetic (never `double`) and a single ROUND HALF UP
rounding step per figure (`roundHalfUpNonNegative`, a small `int`-only
reimplementation of the same ADR-018 policy `MoneyRounding` already
uses for `Decimal`, justified here because every numerator/denominator
involved is already an exact small integer). Leap years are deliberately
not special-cased — the resulting ≈0.07% drift is smaller than the
rounding step itself, and treating it exactly would make the estimate
depend on which specific years a daily/weekly schedule happens to run
through. `monthlyMinorUnits` and `yearlyMinorUnits` are computed
independently from the same rational inputs, each rounded once — never
one derived from the other — so a single rounding step's error is never
compounded twelvefold. Every UI surface that shows these figures labels
them "Est." (`subscriptionsEstimatedMonthlyTotalLabel`/
`subscriptionsEstimatedYearlyTotalLabel`), never presenting them as an
exact accounting total.

**Multi-currency totals are kept separate, always.**
`computeSubscriptionEstimatedTotals` groups by `currencyCode` and returns
one `SubscriptionCurrencyTotal` per currency, sorted by currency code for
a deterministic display order. There is no code path anywhere in this
checkpoint that sums two different currencies' minor-units figures
together, and no reference/live FX rate is consulted to manufacture a
single combined total — if a profile's subscriptions span multiple
currencies, the Subscriptions tab's totals header simply stacks one
block per currency (`_SubscriptionTotalsCard`/
`_SubscriptionCurrencyTotalBlock` in `recurring_screen.dart`).

**Navigation: one screen, two tabs, no new route.** `RecurringScreen`
gained a local `_RecurringTab` enum (`recurring`/`subscriptions`,
defaulting to `recurring`) and an `AppSegmentedControl<_RecurringTab>`
below its `AppBar`, switched via local `setState` — no GoRouter route,
no bottom-nav change (Home/Activity/Add/Profile stays exactly as locked).
The add-rule FAB only renders on the Recurring tab, since a subscription
is created through the exact same "new recurring rule" dialog as any
other expense-kind rule — there is no separate "add subscription" flow
to expose.

**Visual convergence.** The Recurring tab's list body was extracted
unchanged into `_RecurringListView` (byte-identical logic/Keys to the
pre-Checkpoint-11 `RecurringScreen.build`), and `_PendingItemTile`'s
inline `Row`/bare `Text` header was rebuilt on CP10's
`AppFinanceListRow` (icon-led leading tile, title, and a new
frequency-plus-date subtitle) with an `AppMoneyText`/`AppStatusChip`
trailing column replacing the previous single combined
amount-and-date `Text`. The outer `AppCard(bordered: true)` shell, and
every edit/delete/skip/post `Key`/widget type in the `Wrap` beneath it,
are unchanged — preserving every existing `recurring_screen_test.dart`
assertion (including the CP7.5 `Card.color`/`elevation`/`shape.side`
contract and the `findsNWidgets(2)` "Due today" chip-plus-header count).

No Drift schema migration, no new or removed dependency, and no FX/
network/OCR/AI/cloud change. `docs/design/` reference assets were
inspected only for visual direction (the reference's Subscriptions
screen) and were not modified. Deferred to V2 or later, as out of this
checkpoint's explicit scope: OCR, cloud sync, AI, household/family
wallet, bank integrations, automatic subscription cancellation,
subscription-provider APIs, cross-currency accounting, a per-rule
subscription opt-out/tag, and per-category icons on Subscriptions rows
(considered and deferred this checkpoint as unnecessary added
async-state complexity for a V1 pass).

Reason: every V1 requirement — truthful subscription data, deterministic
estimated totals, currency-safe presentation, CP10-consistent visuals —
is achievable as a read-only view over the recurring engine that already
exists and is already tested; building a second accounting concept or a
new schema column would duplicate logic this checkpoint has no evidence
the existing model cannot already express.

Status: Approved 2026-09-20 (Checkpoint 11). Pending Windows verification
(`flutter analyze`; `flutter test test/features/recurring/`; `flutter
test test/widget/recurring_screen_test.dart`; full `flutter test`) — this
sandbox has no Dart/Flutter toolchain and cannot itself execute or
confirm test results.

### Addendum (2026-09-20) — corrected "upcoming" selection: first UNHANDLED future occurrence, not a single lookup

Context: Android manual QA on this checkpoint found the Subscriptions
tab simultaneously showing a non-zero estimated total for a currency
AND the "No active subscriptions yet" empty state — an apparent
contradiction for the same profile at the same moment. Investigation
traced this to `_pendingItemsForRule` (`recurring_providers.dart`, the
function this ADR's "presentation, not a second engine" section above
describes both `subscriptionPendingItemsProvider` and the Recurring
tab's own list as ultimately deriving from): its "upcoming" branch did
exactly one `nextOccurrenceAfter(todayUtc)` lookup and silently
contributed nothing if that single candidate date already had a
posted/skipped `RecurringOccurrences` row — which the Post/Skip
buttons already allow unconditionally, for any urgency including
`upcoming` (there is no repository-side guard rejecting a future
`scheduledDateUtc`, by design — see `RecurringOccurrenceRepository`).
A still-active subscription that had one future occurrence handled
early would therefore vanish from `recurringPendingItemsProvider`'s
(and so `subscriptionPendingItemsProvider`'s) output entirely, while
`computeSubscriptionEstimatedTotals` — which only checks
`recurringScheduleOf(rule).occurrenceOnOrAfter(todayUtc) != null`, never
consulting handled-occurrence state at all — correctly kept counting
that rule. Two independently-correct-in-isolation computations produced
one incoherent screen.

**Fix: a bounded forward walk, not a new selection concept.** The
single lookup was replaced with a loop that calls
[`RecurringSchedule.nextOccurrenceAfter`] repeatedly — no new
calendar/recurrence arithmetic anywhere — starting from `todayUtc`,
advancing past each already-handled date, until it finds the first date
NOT in `handledDates`, or `nextOccurrenceAfter` returns `null` (which it
already does at or before a schedule's own `endDateUtc` — see that
method's existing doc comment). That `null` is this walk's *primary*
termination guarantee for any finite schedule, independent of how many
future occurrences were handled early; a `_kMaxUpcomingScanIterations =
10000` cap is only a *secondary*, defensive backstop for a never-ending
schedule (`endDateUtc == null`) paired with pathological amounts of
handled data — sized against the shortest supported period (daily,
`interval == 1`) so that 10,000 iterations is over 27 years of daily
occurrences, far beyond any realistic amount of legitimate early
posting/skipping, meaning this cap can only ever discard truly
pathological data, never a still-active rule under normal use.

**Deliberately out of scope for this fix**, per explicit product
direction: no guard was added to `RecurringOccurrenceRepository`
rejecting an early Post/Skip — the ability to handle a future
occurrence ahead of time remains a supported, unconditional capability
of the existing engine, exactly as this ADR's "presentation, not a
second engine" section already describes it; accounting/write
semantics, `RecurringEstimate`, subscription classification
(`isSubscriptionRule`), and FX are all unchanged. This addendum
therefore does not revise this ADR's decision — the modeling,
totals-computation, and multi-currency-separation decisions above all
still stand exactly as approved — it only documents the correction to
the shared upcoming-occurrence-selection logic both this ADR's
providers and the pre-existing Recurring tab already depended on.

Regression coverage: `test/features/recurring/presentation/recurring_providers_test.dart`
(three selector-level cases: an already-handled nearest occurrence,
multiple consecutive handled occurrences, and a finite schedule whose
every remaining occurrence is handled) and
`test/widget/recurring_screen_test.dart` (one end-to-end case:
skip a subscription's only Upcoming row via the existing UI, then
assert the later occurrence renders and the Subscriptions tab's totals
card and empty-state message never contradict each other).

Status: Approved 2026-09-20 (Checkpoint 11 final fix). Pending Windows
verification (`flutter analyze`; `flutter test
test/features/recurring/`; `flutter test
test/widget/recurring_screen_test.dart`; full `flutter test`) — this
sandbox has no Dart/Flutter toolchain and cannot itself execute or
confirm test results.

## ADR-032 — Checkpoint 12.1: cloud account + sync architecture audit and V1 contract (no sync implemented)

Context: CP12 is high-risk because cloud sync can affect financial data
integrity. CP12.1 is an audit-and-contract-definition checkpoint only —
no cloud sync, authentication, networking, or backend was implemented.
The full audit, with per-table findings, is
`docs/21_CLOUD_SYNC_ARCHITECTURE.md`; this entry records the decisions
that document reaches, for the decision log's own cross-referenced
history.

**The app remains local-first, unconditionally.** Every existing local
capability — transaction capture, balance computation, budgets, savings
goals, recurring rules/occurrences, transaction history — must keep
working offline, signed out, and with the cloud service unavailable or
failing. Sync is designed throughout as an additive layer on top of an
already-sufficient local source of truth, never a new dependency of
ordinary local operation.

**Schema audit finding: the offline-ID design was already correct.**
Every syncable table's primary key is a client-generated UUIDv4, minted
once at creation and never remapped by any repository method — confirmed
directly in code across all twelve tables. This was a deliberate Beta 0
decision (the `uuid` package's own `pubspec.yaml` comment: *"Client-
generated IDs for offline-first writes"*), not something CP12.1 had to
retrofit. Go/no-go answer for CP12.2+: **GO** — no ID scheme blocks V1
sync.

**Schema audit finding: two small, additive gaps, and one dormant table
-- corrected, CP12.2.** `accounts` (a v1/Beta-0 table) never received
the `sync_version`/`sync_status` pair every schema-v2-onward table
already has. `categories` has none of
`created_at`/`updated_at`/`deleted_at`/`sync_version`/`sync_status` at
all, and has no update or delete method of any kind today. These two
gaps are the only migrations actually committed for CP12.3, specified in
`docs/21_CLOUD_SYNC_ARCHITECTURE.md` §11. `transaction_exchange_rates`
(reserved since v1, still unused in production — nothing calls `attach`
from any live transaction flow yet) is explicitly **not** a third
committed migration -- it would need the same five columns only once/if
it is ever wired into a real feature, and no step in the CP12.2-CP12.7
roadmap plans to do so. (CP12.1's original final report described this
as "four small, additive migrations," miscounting an earlier version of
§11's table that listed `categories`' columns across three separate
rows; §11 now states the count as two committed migrations plus one
explicitly deferred/conditional table, and this entry is corrected to
match.) None of this blocks CP12.1 or CP12.2.

**Schema audit finding: `sync_version`/`sync_status` are inert
placeholders today, not yet real state.** Every write path across every
table leaves them at their column defaults (`0`/`'localOnly'`) — exactly
as ADR-020 always intended them to sit until Stage 6. No code increments
`sync_version` or transitions `sync_status` anywhere yet. CP12.3 must
give them real semantics (a monotonic per-record mutation counter; a
genuine pending/pushed/synced/conflict state machine) reusing these exact
existing columns — this requires no further schema change, only
application logic.

**Identity decision: the existing `profiles` row must NOT become the
cloud auth identity.** `ProfileRepository`'s own documented invariant is
exactly one local profile per install, with no multi-profile concept
anywhere in its API, no `deleted_at`, and no sync fields at all — the
wrong shape for a server-verified, multi-device identity. V1 instead
keeps LOCAL PROFILE (today's table, unchanged, preferences/locale only)
strictly separate from a new CLOUD IDENTITY concept: a server-assigned
`cloud_user_id`, linked to the local profile by one small local record,
resolved server-side from the session on every request and never trusted
from client input. Household/shared-wallet identity is explicitly left
to `20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` V2 §6 and is not
redecided here.

**Sync envelope decision: four distinct numbers, never conflated.** Local
Drift `schemaVersion` (whole-database shape), per-record `sync_version`
(client's own mutation count), `server_revision` (server's authoritative
per-record count, used for conflict detection), and `client_mutation_id`
(a fresh idempotency key per mutation attempt, reused verbatim across
retries of that attempt) answer four different questions and must never
be compared to one another.

**Conflict policy decision: per entity class, never a single global
last-write-wins.** Preference-shaped fields may auto-merge safely;
anything that determines an amount, currency, type, active/deleted
state, or a recurrence-math-relevant date never auto-merges — the
server-accepted `server_revision` wins and the losing edit is preserved
and surfaced, never silently discarded or blended into a fabricated
merged record. Full per-entity table in `docs/21_CLOUD_SYNC_ARCHITECTURE.md`
§5.

**Deletion decision: tombstones only, indefinitely, for every syncable
table; the one existing hard delete (`reference_exchange_rates.removeIfPresent`)
stays exactly what it already is — a device-local cache operation on
non-financial data, never a precedent for hard-deleting anything else.**
No retention/purge policy is designed in CP12.1, per the checkpoint's own
instruction not to invent one prematurely.

**Backend contract decision: the server never trusts a client-supplied
ownership/user id — every push/pull is scoped to the caller's
authenticated session identity, resolved server-side, full stop.** This
is the single most important server-side rule this audit establishes;
every domain invariant the local repository layer already enforces
(ADR-017/018/019/021/022/023's precedents) must be re-enforced
independently on the server, never assumed satisfied because a client
already checked it.

**What must not sync, decided per item, not by table-by-table
default:** the reference-FX cache, notification-scheduling artifacts,
transient UI/filter state, theme/language preference (V1), currency-
converter favorites, local reminder ids, derived account balances,
derived subscription estimates, the seeded `currencies`/system-`categories`
data, and the sync engine's own local bookkeeping (mutation queue, pull
cursor, device/install id) — each justified individually in
`docs/21_CLOUD_SYNC_ARCHITECTURE.md` §10 rather than assumed.

No Dart production code was changed for this checkpoint. No Drift
migration was performed — §11's additive migrations are specified for
CP12.3, not applied now. `docs/design/` was not inspected or modified.

Reason: CP12 is too high-risk to design the sync engine and the schema
migration in the same pass as the audit that determines what they need
to be. Auditing first, against the actual code rather than an assumed
architecture, is what let this entry conclude "GO" on the hardest
go/no-go question (ID survivability) with direct evidence, and caught
two real gaps (`accounts`/`categories` sync-field coverage) and one
inert-placeholder risk (`sync_version`/`sync_status`'s current
semantics) that a sync implementation written without this audit could
easily have missed or gotten wrong on the first attempt.

Status: Approved 2026-09-20 (Checkpoint 12.1 — audit and contract only).
No Windows verification is required for this checkpoint (no Dart code
changed, no schema migrated, nothing to `flutter analyze`/`flutter test`
beyond what CP11's baseline already covers) — the deliverable is
`docs/21_CLOUD_SYNC_ARCHITECTURE.md` plus this entry. CP12.2 begins
implementation against the contract this entry and that document define.

## ADR-033 — Checkpoint 12.2: cloud identity / auth foundation (no financial sync, no mutation queue)

Context: `docs/21_CLOUD_SYNC_ARCHITECTURE.md` (CP12.1) defined the V1
cloud identity/account contract (§3) without implementing any of it.
CP12.2's task was to implement exactly that contract's minimum
foundation — a local representation of "this profile is linked to one
authenticated cloud user," a replaceable auth/session provider boundary,
and the UI to show it — while explicitly not implementing financial-data
synchronization, the mutation queue, or any change to
`sync_version`/`sync_status` semantics.

**Identity decision: LOCAL PROFILE and CLOUD IDENTITY stay two separate
concepts, exactly as §3.2 specified — `profiles` is untouched.** The link
between them is a new, tiny, local-only table (`cloud_account_links`),
not a nullable column added to `profiles` — keeping the existing
profile's access pattern (`ProfileRepository`'s "exactly one row per
install" contract) completely unchanged, and keeping cloud-identity
bookkeeping out of a table that is also-read/written for ordinary
locale/theme preference edits.

**Schema decision: one additive migration, schema version 7 -> 8, one
new table, no backfill.** `cloud_account_links` uses `profile_id` (a
foreign key into `profiles`) as its PRIMARY KEY rather than a surrogate
`id` — the same natural-key departure `reference_exchange_rates`
established in ADR-011/CP9.3, for the same reason: V1 supports at most
one cloud account per device, and Beta 0/1 already guarantee at most one
local profile per install, so a natural key makes "at most one row" true
by construction rather than by an unenforced application rule. The table
deliberately has no `deleted_at`/`sync_version`/`sync_status` — this is
device-local link bookkeeping (which cloud account THIS INSTALL
currently considers itself linked to), never synced user data, per
`docs/21_CLOUD_SYNC_ARCHITECTURE.md` §10's "what must not sync" boundary.
It stores no token, password, or secret of any kind, and no email or
display name (V1 has no real backend to source those from truthfully).

**Auth provider decision: an abstract `CloudAuthProvider` interface, two
implementations, exactly one of which production ever sees.**
`UnavailableCloudAuthProvider` is production's only implementation —
`isAvailable` is permanently `false`, `signIn()` always throws rather
than fabricating a session, matching the checkpoint's explicit "do NOT
fake successful production authentication" instruction as a structural
guarantee rather than a convention someone could accidentally violate
later. `InMemoryCloudAuthProvider` is a clearly-labeled, purely
in-memory development/test-only fake, never imported by
`lib/main.dart`/`lib/app/app.dart`.

**Dependency decision: no new package was added, and the checkpoint's
STOP-before-adding-a-dependency instruction was not triggered.** No real
backend exists yet, so production never has a real token to persist —
there is nothing today for a real `flutter_secure_storage`-backed
`SecureTokenStore` implementation to protect. The interface is defined
now (`lib/core/cloud_identity/secure_token_store.dart`) so that a future
checkpoint that adds both a real backend and a real token only ever adds
one new class behind it; adding `flutter_secure_storage` (the recommended
choice when that day comes) is that future checkpoint's STOP-and-report
decision, not retroactively this one's.

**Account-switch-safety decision: refuse a different-account sign-in
outright; no reset/merge flow.** `CloudAccountLinkRepository.recordSignIn`
throws `DifferentCloudAccountLinkedException` whenever this device
already has a link to a cloud account other than the one being signed
into — including after an explicit sign-out, since `cloud_user_id` is
deliberately remembered across a sign-out specifically to make this
detectable. This is the minimum safe behavior the checkpoint asked for:
existing local financial data is never silently reassigned between cloud
users, full stop, with no UI path around it in V1. `§12`'s original
"deferred to CP12.2 for the exact UX" note (in
`docs/21_CLOUD_SYNC_ARCHITECTURE.md`) is only partially resolved by this
— the mutation-queue-aware version of that decision (refuse while
mutations are pending vs. an explicit reset flow) still needs a real
queue to exist first, and remains CP12.5/CP12.6's to design.

**UI decision: 4 truthful states, never a sync claim.** The new Cloud
Account screen renders `unavailable` / `local-only` / `signed in` /
`session expired` via the existing `AppStatusChip`, and never renders
"Synced," "Backed up," or "Up to date" in any state — those claims would
be false today (financial sync does not exist) regardless of which of
the 4 identity states is active. `unavailable` is the only state a real
production user can reach in this checkpoint, since
`UnavailableCloudAuthProvider` is production's only provider.

No Dart production code outside the paths listed above (and the small
`app.dart`/`settings_screen.dart`/`app_routes.dart`/`app_router.dart`/
`providers.dart` wiring edits) was touched. No existing test was
weakened. `docs/design/` was not inspected or modified.

Reason: CP12.1 identified identity/auth as the one piece of the sync
architecture that could be built safely before any backend exists,
precisely because its correct V1 shape is "truthfully represent that
nothing real has happened yet" rather than "talk to a real system."
Building the abstraction boundary now — with a truthful production
implementation and a clearly-fake development one behind the same
interface — means the eventual real backend integration (CP12.3+)
changes zero call sites, only adds one class.

Status: Approved 2026-09-20 (Checkpoint 12.2 — cloud identity / auth
foundation implemented; no financial-data sync, no mutation queue, no
`sync_version`/`sync_status` change). Windows verification required:
`dart run build_runner build --delete-conflicting-outputs`, then
`flutter analyze` and `flutter test` against this branch — see this
checkpoint's final report for the exact focused test files. CP12.3
begins the local sync-state/mutation-queue work against the schema
migrations `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §11 already specifies.
