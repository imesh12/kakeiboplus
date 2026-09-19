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

Status: Approved 2026-09-18 (Checkpoint 9.4).
