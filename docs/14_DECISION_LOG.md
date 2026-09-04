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
