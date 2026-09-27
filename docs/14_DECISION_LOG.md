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

## ADR-034 — Navigation architecture decision: five-destination primary shell (HOME / ACTIVITY / + ADD / ACCOUNTS / MORE)

Status: Approved 2026-09-20 (documentation/architecture decision only; no implementation
in this checkpoint).

**Decision: replace the primary navigation shell's destination set.** The primary
bottom-navigation shell moves from the four destinations implemented at HEAD `02dd471`
(Home / Activity / center Add / Profile) to five approved destinations: **HOME / ACTIVITY
/ + ADD / ACCOUNTS / MORE**. Add remains a center action, not a fifth tab page. This
decision is recorded in full, including the final V1 page tree, the More hierarchy, the
eight-screen UI-reference mapping, and the V2 expansion mapping, in
`docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26. That section is authoritative for
navigation; the navigation-related content in that document's earlier sections (1, 4, 5,
6, 14, 20, 21, 22, 23, 25) is superseded but retained as historical record, per that
document's own no-silent-rewrite discipline.

**Rationale:**

- Home = financial health at a glance (balance, income/expense, budget/goal status,
  upcoming) — unchanged in purpose from the previous shell.
- Activity = financial history (the full transaction ledger) — gets its own permanent
  slot rather than being reached only through Home links.
- Add = capture (Expense / Income / Transfer) — unchanged center action.
- Accounts = money locations and what is owed (cash, bank, cards, credit-card
  liabilities) — promoted to a primary top-level tab because it is a core financial
  object, not a secondary tool. It was previously reachable only via a Home shortcut and
  a Profile row.
- More = planning tools, recurring, preferences, identity/security, and about — the
  destination Profile previously occupied, renamed and reorganized (Planning / Recurring
  / Money Tools / Organization / Personalization / Cloud & Security / About) to match what
  it actually contains now that Accounts has moved out of it. Profile itself was judged
  too low-frequency a *destination* to keep a permanent primary slot once Accounts needed
  one; its content is not dropped, only relocated under More.
- This five-destination shell is deliberately structured so that V2 growth — Assets &
  Liabilities (under Accounts), Receipt Scanner/OCR and Family Wallet (under More /
  +Add), a richer Activity, and receipt-assisted +Add capture — fits inside the existing
  five destinations without requiring another shell redesign. Receipt OCR remains the
  first major V2 feature (per ADR-029); Family Wallet remains V2, gated on cloud
  identity/sync/permissions/invites/conflict handling/audit as recorded in
  `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §13.

**Explicitly rejected:** copying the user-supplied eight-screen UI reference's own
navigation row (Home / Accounts / + / Budgets / More) verbatim. That reference keeps
Budgets as a permanent tab and has no Activity slot; this decision instead gives Activity
the permanent slot and keeps Budgets as a linked page reachable from Home and More. The
reference image's navigation was not treated as authoritative even under the previous
navigation decision, and remains non-authoritative here — only the reference's visual
language (section 17 of doc 22) is a design target, not its tab bar. Profile, Categories,
and Budgets are explicitly excluded from the bottom-navigation destination set.

**Scope of this decision: information architecture only.** This ADR and
`docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 freeze the approved navigation
structure for future implementation. They do not modify `AppShell`, `GoRouter`, any
navigation widget, production Dart, tests, database schema, or localization resources.
`AppShell`/`app_router.dart` at HEAD `02dd471` continue to implement the previous
four-destination shell; implementing the five-destination shell approved here is future
work for a separate, explicitly scoped implementation checkpoint. No Dart, test, schema,
or routing files were touched to record this decision, and nothing was staged or
committed by it.

Reason: the product owner determined that Accounts — where money is held and what is
owed — needed to be a primary navigation destination rather than a secondary shortcut,
and that this could not be done by simply adding a fifth slot to the existing shell
without also reconsidering which destination it displaced. Profile's tool-directory role
survives under a new name (More) rather than being removed, and the resulting
architecture is designed to absorb the product's near-term V2 roadmap (wealth, OCR,
household sharing) without forcing a second navigation redesign later.

## ADR-035 — Unified `FinancialAccount` ledger model: design freeze for asset/liability accounts, payment instruments, and deposits

Status: Approved 2026-09-20 (documentation/architecture decision only; no
implementation in this checkpoint).

**Decision: adopt a single, unified `FinancialAccount` ledger-target table**
(rather than parallel per-type tables that `Transactions` would need separate,
mutually-exclusive foreign keys to reference) as the authoritative balance
target for every asset and liability account. A `FinancialAccount` carries a
`balanceClass` (`asset` | `liability`) and a `subtype`; specialized products
attach one-to-one metadata via `CreditFacilityDetails`/`DepositDetails` rather
than widening `FinancialAccount` itself with mostly-unused nullable columns.
`PaymentInstrument`s (debit/credit cards, linked wallets) are never
balance-holding and link to exactly one `FinancialAccount`. This decision is
recorded in full — domain model, immutability invariants, canonical balance
sign semantics, transaction/payment-instrument invariants, the shared-credit-
facility shape, the deposit model and its deterministic calculation contract,
the recurring-deposit and wallet-funding scope decisions, the conservative
migration policy from today's `accounts.type` free-text data, compatibility
with the existing generic Account Detail/Edit screens (HEAD `deb51bf`), the
V1/later scope table, and the ordered implementation checkpoint plan — in
`docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §12–13. That document is
authoritative for this model's detail; this entry records the decision itself
for the decision log's own cross-referenced history, matching the existing
ADR-023/§10.6 and ADR-032/§21 precedent of a decision-log entry pointing to a
fuller specification document rather than duplicating it.

**Rationale — why unified over parallel per-type foreign keys:** An earlier
audit pass proposed making `Transactions.accountId` nullable and adding a
parallel `creditFacilityId` column, with an application-enforced
"exactly one of the two" rule. A subsequent adversarial comparison against the
unified alternative found the parallel design loses on nearly every axis
evaluated: it requires widening an existing, populated, required column
(`accountId`) to nullable on the schema's highest-write-frequency table — a
strictly riskier migration primitive than the unified model's own migration,
which touches `Transactions` not at all; it introduces a genuinely new
mutually-exclusive-FK-pair invariant with no precedent in this schema, and that
invariant would have needed to repeat for every future liability type (loans,
etc.) and again for `PaymentInstrument`s, whereas the unified model needs it
zero times; it fragments balance arithmetic into two independently-written
`FinanceEngine` functions that must separately agree on transfer-destination
behavior, reintroducing exactly the "one missed branch flips a sign" risk the
split was originally meant to avoid; and it makes net worth and future
liability types each require a growing list of tables to remember to sum over,
where the unified model always sums over one table. The one point in the
parallel design's favor — that which table a row lives in can never be edited
by an ordinary `UPDATE`, giving `balanceClass` immutability "for free" — is
preserved in the unified model by a deliberate, explicit design requirement
(§12.2): the repository's own update-method signature must have no way to
express a `balanceClass`/`subtype` change at all, the same discipline this
codebase already trusts for currency immutability, backed by a required
regression test rather than left to convention.

**Explicitly deferred, not decided against:** a loan amortization engine, full
recurring-deposit auto-posting/projection, bank-specific tax/day-count rules,
early-withdrawal calculations, variable-rate deposits, net worth as a
screen/provider, and refund-to-credit-card all remain future work under this
same model — this decision does not foreclose any of them, it only declines to
build them now. See `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.3
for the full V1/later classification.

**Scope of this decision: information architecture only.** This ADR and
`docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §12–13 freeze the approved
domain model, invariants, and implementation sequencing for future work. They
do not modify the Drift schema, `FinanceEngine`, any repository, provider,
screen, test, or localization resource. `accounts`/`Transactions` at HEAD
`deb51bf` continue to implement exactly what they implemented before this
entry; implementing checkpoint B of the ordered plan (§13.4) is future work for
a separate, explicitly scoped checkpoint. No Dart, test, schema, or migration
file was touched to record this decision, and nothing was staged or committed
by it.

Reason: the product's real-world account acceptance cases (multi-product
institutions, shared-limit credit cards, debit cards that must never duplicate
a bank balance, term/fixed/recurring deposits) could not be represented
correctly by the flat `accounts.type` free-text model, and two candidate
schema shapes were evaluated in detail — including an explicit attempt to
falsify each — before this one was adopted, rather than committing to the
first design that appeared adequate.

## ADR-036 — Checkpoint M: KakeiboPlus product identity and branding

Status: Implemented 2026-09-26 (product identity/branding checkpoint on top of
`62ccd4b`; no financial/domain logic touched).

**Decision: the product's official visible name is KakeiboPlus.** This
checkpoint updates every user-visible surface that names the app (the OS
task-switcher title via `MaterialApp.title`, the installed Android
application label, and the iOS `CFBundleDisplayName`/`CFBundleName`) to
"KakeiboPlus", replacing the previous "AI Financial Coach"/"Ai Financial
Coach" strings. It deliberately does **not** touch the Dart package name
(`ai_financial_coach`, used in every `package:ai_financial_coach/...` import
across the codebase), the Android `applicationId`/`namespace`
(`com.example.ai_financial_coach`), the iOS `PRODUCT_BUNDLE_IDENTIFIER`
(`com.example.aiFinancialCoach`), or the on-disk SQLite filename
(`ai_financial_coach.sqlite` in `native_connection.dart`) — renaming any of
those is a genuinely separate, higher-risk migration (an app/bundle-identifier
change can break update continuity on real devices; the SQLite filename is
load-bearing storage, not display text, and renaming it would orphan every
existing installed user's database) that this branding-only checkpoint has no
reason to take on. Both are recorded here as an explicit, intentional
deferral, not an oversight: `com.example.*` should be revisited as its own
release-readiness decision before any real store submission.

**Branding source assets — role decision.** Four source PNGs live in
`assets/branding/` (left byte-for-byte untouched by this checkpoint; every
platform/in-app usage below is a derived, resized, or separately-encoded copy,
never an edit of the originals):

- `kakeiboplus-app-icon.png` (1254×1254, its own baked-in rounded-square
  gradient background plus a bold white "K" + green leaf + amber "+"
  monogram, reads clearly even at 48px) is the only one of the four already
  shaped like a launcher icon. Used for the Android and iOS launcher icon.
- `kakeiboplus-primary-logo.png` (1254×1254, the same monogram on a
  *transparent* background, no background chip) is the foreground-only
  counterpart of the icon above. Not used in-app this checkpoint; reserved as
  the natural source for a future Android adaptive-icon foreground layer, if
  that migration happens later (see "Deferred" below).
- `kakeiboplus-wordmark.png` (2172×724, transparent background, "KakeiboPlus"
  in a two-tone green logotype, no tagline) is the one asset suited to
  showing the full product name. Used once, on the More screen (see below).
- `kakeiboplus-wallet-growth-logo.png` (1254×1254, a wallet/growth
  illustration *with the wordmark and an English tagline, "Money made
  simple.", already baked into the pixels*) is a composite marketing/store-
  listing graphic, not a UI asset: its fixed English tagline cannot be
  localized for Japanese, and it is too detailed to read at any in-app icon
  size. Deliberately **not** used in-app this checkpoint (reserved for store-
  listing/marketing use outside the Flutter bundle) — this is a considered
  exclusion, not "display all four assets because they exist."

**Launcher icon strategy.** The project already used plain legacy mipmap PNGs
(`android/app/src/main/res/mipmap-*/ic_launcher.png`, no adaptive-icon XML,
no `flutter_launcher_icons` dependency) and a standard `AppIcon.appiconset`
with an existing `Contents.json`. This checkpoint keeps that exact mechanism
rather than introducing a new one: all 5 Android density PNGs (mdpi 48,
hdpi 72, xhdpi 96, xxhdpi 144, xxxhdpi 192) and all 15 iOS `Contents.json`
entries (20/29/40/60/76/83.5pt at their declared `@1x`/`@2x`/`@3x` scales,
plus the 1024 marketing icon) were regenerated as resized copies of
`kakeiboplus-app-icon.png`. The iOS copies are additionally flattened onto an
opaque white background (`-alpha remove -alpha off`): Apple requires a fully
opaque icon with no alpha channel, and the source PNG's rounded corners and
soft edge blur carry transparency that iOS's own corner-mask expects to be
opaque square content underneath, not letterboxing. No new package
dependency was added for this.

**Android application label.** `AndroidManifest.xml`'s `android:label` was
switched from the inline literal `"ai_financial_coach"` to `@string/app_name`,
backed by a new `android/app/src/main/res/values/strings.xml` defining
`app_name = "KakeiboPlus"` — the project had no `strings.xml` before this
checkpoint, so this is a clean, minimal addition rather than a restructuring.
No permission, activity, intent-filter, signing, or unrelated Gradle setting
was touched.

**iOS display name and icon.** `Info.plist`'s `CFBundleDisplayName` ("Ai
Financial Coach" → "KakeiboPlus") and `CFBundleName` ("ai_financial_coach" →
"KakeiboPlus") were updated; `PRODUCT_BUNDLE_IDENTIFIER` in the `.pbxproj` was
left untouched (see the package/bundle identifier decision above). The iOS
launch screen (`LaunchScreen.storyboard` / `LaunchImage.imageset`) was
deliberately **not** touched: its existing `LaunchImage`/`@2x`/`@3x` files are
68-byte placeholder stubs from the original Flutter template, never replaced
with real artwork, and the supplied source assets are not pre-cropped to that
imageset's required point sizes/aspect ratio. Hand-editing an Xcode
Interface-Builder `.storyboard` XML file without Xcode itself to validate it
carries real corruption risk for a benefit (a splash image) explicitly marked
optional/conservative-only in this checkpoint's own brief; this is recorded
as an intentional deferral, not a gap discovered by accident.

**Android splash.** `launch_background.xml` (both the default and `-v21`
density-independent variant) already contained a commented-out example
showing exactly how to add a centered bitmap. This checkpoint uncomments that
exact pattern, pointing at the same `@mipmap/ic_launcher` this checkpoint just
regenerated — no new asset, no new dependency, no artificial startup delay,
no animation.

**Flutter runtime asset registration.** `pubspec.yaml` gained one `assets:`
entry, `assets/branding/kakeiboplus-wordmark.png` — the only one of the four
branding images actually loaded via `Image.asset` at runtime. The other three
are consumed as platform-native derived resources (copied/resized into
Android/iOS locations above, which do not go through Flutter's asset bundle)
or are unused in-app this checkpoint (the wallet-growth illustration); neither
is registered, per "register only what's actually required." The registered
filename has no spaces, unlike this repo's existing `docs/design/*` reference
images, so it is safe on case-sensitive filesystems and Windows alike.

**In-app brand placement.** Home was audited and deliberately left
**unchanged**: it must stay a financial dashboard first (per this checkpoint's
own UX principle and the pre-existing Checkpoint J privacy architecture — Net
Worth is still reachable only via More → Net Worth, never shown on Home), and
a large decorative logo there would compete with the balance/budget/goal
information that screen exists to show. The one place branding was added is
the **More screen**: a small, non-interactive, non-tappable card at the very
top of its existing `ListView` (above the pre-existing subtitle), showing the
KakeiboPlus wordmark. This matches "More/About is an appropriate place for
stronger product identity" without inventing a new About screen/route this
checkpoint did not ask for (`more_screen.dart`'s own pre-existing doc comment
already records that About has no real V1 screen/route, and adding one is out
of scope for a branding checkpoint). The wordmark's ink is a fixed brand
green, not `colorScheme`-derived; on this app's Dark/Ocean/Forest themes'
dark `colorScheme.surface`, that fixed dark-green text would be close to
unreadable, so the card wraps it in a small fixed off-white background,
independent of the active theme — the same way a logo badge conventionally
stays on-brand regardless of a host app's own theme, rather than a "recolor
the whole screen" change.

**Accessibility.** The wordmark image carries a single `Semantics(label:
l10n.brandName, image: true)` wrapping an `ExcludeSemantics`-guarded `Image`,
mirroring the exact `Semantics(...) → ExcludeSemantics(child: ...)` idiom
`theme_customization_screen.dart` already uses for a decorative-but-labeled
visual: one meaningful announcement ("KakeiboPlus"), not a noisy nested
semantics tree. No navigation or financial information is encoded only inside
this image.

**Localization.** One new key, `brandName` = "KakeiboPlus", was added to both
`lib/l10n/app_en.arb` and `lib/l10n/app_ja.arb` with an identical value and an
explicit translator-facing `description` warning it must never be translated
— it is the accessibility label for the wordmark, and "KakeiboPlus" is a
proper/brand name by requirement, not a translatable string.
`MaterialApp.title` itself stays a literal Dart string rather than an
`AppLocalizations` key: it is consumed by `WidgetsApp` before `Localizations`
resolves, so it has no access to `l10n` at that point regardless, and a
literal string is the most direct way to guarantee it reads identically in
every locale.

**Explicitly deferred, not decided against:** the `com.example.*`
Android/iOS package and bundle identifiers (a release-readiness decision, not
a branding one); the iOS native launch-screen image (source artwork not
pre-cropped for it, and hand-editing the storyboard XML blind is a needless
risk for an optional splash-image polish item); an Android adaptive icon
(foreground/background split) migration, for which `kakeiboplus-primary-
logo.png` is already the correctly-shaped source when that work happens; and
any in-app usage of `kakeiboplus-wallet-growth-logo.png` (reserved for
external/marketing use, given its baked-in non-localizable English tagline).
None of these is a defect in this checkpoint — each was a considered
boundary, recorded so it is not silently forgotten.

**Scope of this decision: product identity/branding only.** This ADR does not
modify the Drift schema, `FinanceEngine`, any repository, provider, account/
transaction/budget/goal/dashboard/net-worth calculation, or the Home screen.
`docs/design/*` reference files were not touched. Nothing was staged or
committed by this checkpoint.

## ADR-037 — Checkpoint N: Cheque/Check Management persistence and accounting model

**Context.** Cheques/checks (issued and received) needed first-class tracking with a real
lifecycle (pending/cleared/bounced/stopped/cancelled), never as a transaction memo, a widget
boolean, or parsed text. The core question this ADR resolves: what persists a cheque, and how
does its accounting effect reach the existing deterministic ledger without teaching
`FinanceEngine` anything new.

**Decision.** Two new, purely additive Drift tables at schema v13:

- `ChequeBooks` — one-to-many per eligible asset account (`bank`/`savings` subtype only),
  the same shape `PaymentInstruments` already established for "reusable metadata attached to
  an account, zero ledger balance of its own, soft-deleted/archived rather than hard-deleted."
- `Cheques` — one row per physical cheque (issued or received), carrying its own amount,
  currency, counterparty, dates, status, and an optional `transactionId` link — the same
  "pending thing lives in its own table; a `Transactions` row is created only once it
  actually posts, and the link is a stable id, never a memo/description parse" pattern
  `RecurringOccurrences` already established for scheduled-but-not-yet-posted money.

Clearing a cheque calls the completely unmodified `TransactionRepository.recordExpense`
(issued) / `recordIncome` (received) inside the same `AppDatabase.transaction` that updates
the `Cheques` row — `ChequeRepository.markCleared` re-checks "is this still pending?" **inside**
that transaction (the exact idempotency pattern `RecurringOccurrenceRepository.postOccurrence`
already uses), so calling it twice always throws on the second call rather than posting twice.

**Why not model a cheque as a `PaymentInstrument`, a `Transactions` row, or a widget-only
concept.** A `PaymentInstrument` is reusable "how you pay" metadata with no per-instance
amount/date/lifecycle — a chequebook fits that shape, but an individual cheque does not. A
`Transactions` row IS a posted ledger entry from the moment it exists (`FinanceEngine` folds
every non-deleted row unconditionally) — there is no "pending transaction" concept anywhere in
this schema, and inventing one inside `Transactions`/`FinanceEngine` would be exactly the kind
of core-engine change this checkpoint's brief said to avoid unless demonstrated necessary. It
was not necessary: keeping the pending cheque in its own table, with zero rows in `Transactions`
until it clears, is both simpler and already proven by the `RecurringOccurrences` precedent. A
widget-only/memo-text representation would have made "did this cheque already post" and "has
this cheque's number been used before" unanswerable without re-parsing free text — explicitly
forbidden by this checkpoint's brief.

**Accounting consequence (the part that matters for user trust).** A pending cheque — issued or
received — posts zero `Transactions` rows and is therefore invisible to `FinanceEngine` and
every dashboard/net-worth provider by construction: a pending issued cheque never reduces the
drawing account's cleared balance, and a pending received cheque is never counted as
available/liquid money. `FinanceEngine`, `dashboard_providers.dart`, and
`net_worth_providers.dart` needed zero source changes — none of them was ever touched by this
checkpoint.

**Lifecycle freeze.** `pending` is the only status every other status is reachable from —
`cleared`/`bounced`/`stopped` (issued only)/`cancelled` (either direction) are each a dead end in
V1. There is no bounce-after-clear reversal and no clear-after-bounce recovery; both are
explicit, recorded deferrals (see the full report), not oversights — building either safely
would require an explicit compensating-transaction mechanism this checkpoint does not attempt.

**Cheque-number scope.** Uniqueness is an application-layer invariant (matching
`RecurringOccurrences`/`BudgetRepository`'s own precedent, never a database constraint),
scoped to `(chequeBookId, chequeNumber)` for an issued cheque, and deliberately unconstrained
for a received cheque — an external payer's numbering is never the user's to control.

**Account eligibility.** `balanceClass: asset` and `subtype` in `{bank, savings}` — derived from
the existing `FinancialAccountSubtype`/`BalanceClass` architecture (§12.1-§12.3 of
`docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md`), never a name heuristic, matching
`CreditFacilityRepository`/`DepositRepository`'s own eligibility checks exactly.

**Scope of this decision: cheque persistence, lifecycle, and accounting semantics only.** This
ADR does not modify `FinanceEngine`, any existing repository's behavior, the dashboard/net-worth
calculation, or the Home screen. See
`docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.16 for the full implementation record,
including every file changed, test coverage, and the complete list of legitimate deferrals.

## ADR-038 — Checkpoint O: Credit Card is a presentation layer over the existing liability/credit-facility architecture, not a new accounting engine

**Context.** Credit Card (`FinancialAccountSubtype.creditCard`, `BalanceClass.liability`) and its
`CreditFacilityDetails` metadata table have existed since Checkpoint E. The question this
checkpoint answers: does the user actually understand their credit card — what they owe, their
limit, their available credit, their utilization, and that credit capacity is debt capacity, not
cash — and if any of that is missing, does filling the gap require new accounting engine work or
only presentation and one small write-path addition.

**Decision.** No new accounting engine. The audit (docs/20 §13.17) found `FinanceEngine`'s
liability effect table, the dashboard/net-worth providers, and cheque eligibility already
correct and already fully excluding credit limit/available credit from every ledger
calculation — none of them reads `CreditFacilityDetails` at all, so credit capacity has zero
ledger weight by construction, not by new filtering logic. Add Account already supported
entering a credit limit at creation. The only two real gaps were: no way to *edit* an existing
card's limit, and no UI anywhere that *showed* credit limit, available credit, or utilization.

Both gaps were closed with the smallest coherent addition: `CreditFacilityRepository
.updateCreditLimit` (writes only `creditLimitMinorUnits`/`updatedAt`, never touches `Accounts`,
never posts a `Transactions` row), and `CreditFacilityPresentation` — a pure, unpersisted class
computing `availableCredit = max(0, limit - owed)` (display-clamped so an over-limit balance
never shows negative "spending capacity") and `utilizationPercent = owed / limit * 100`
(deliberately unclamped, so an over-limit balance shows e.g. 110% rather than being hidden).
Both values are derived on every read, never persisted, never added as a schema column.

**Why not a schema migration.** `creditLimitMinorUnits` already existed and already
round-tripped through Add Account. Available credit and utilization are pure functions of two
`Money` values every screen already resolves — persisting either would create a second source
of truth that could drift from the limit/balance it was computed from, with zero benefit.
`schemaVersion` is unchanged by this checkpoint.

**Why not a `FinanceEngine` change.** Presentation calculations (available credit, utilization)
do not belong in the deterministic ledger engine merely because they involve money — they are
never authoritative financial totals, never feed a balance/budget/net-worth calculation, and
the engine's existing liability effect table (expense increases owed; a transfer-in payment
decreases it; overpayment throws rather than inventing a "credit balance" concept) was already
correct and needed no change.

**Accounting invariants reconfirmed by this checkpoint's audit and tests, not altered by it:**
credit limit and available credit are metadata with zero ledger weight; only the amount owed
drives Net Worth and is excluded from available/liquid money exactly as before; spending and
payments still flow through the completely unmodified `TransactionRepository`/`FinanceEngine`
paths; editing a card's limit never creates a `Transactions` row and never changes the account's
balance; a credit card remains categorically cheque-ineligible (excluded by both `isAsset` and
its subtype, independently); close/reactivate already preserved `CreditFacilityDetails`
correctly and still does.

**Scope of this decision: Credit Card presentation and the limit-edit write path only.** This
ADR does not modify `FinanceEngine`, any existing repository's ledger behavior, the
dashboard/net-worth calculation, cheque eligibility, or account lifecycle. See
`docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.17 for the full implementation record,
including every file changed, test coverage, and the complete list of legitimate deferrals
(statement accounting, APR, billing cycles, minimum payments, and the rest of the explicitly
deferred feature set).

## ADR-039 — Checkpoint P: Deposit maturity is presentation over an already-complete architecture; deposit-field editing is a deliberate, documented V1 non-goal

**Context.** Deposit/Term Deposit accounts have had full persistence (`DepositDetails`), a pure
maturity-status function (`DepositStatus.fromMaturityDate`), and an Account Detail presentation
section since Checkpoints F/J. The question this checkpoint answers: is anything actually
missing from the V1 deposit experience, and specifically, does "maturity" ever leak into
account lifecycle, available money, or Net Worth — and separately, should Edit Account let a
deposit's rate/term/start/maturity be changed after creation.

**Decision.** Nothing in production needed to change. The audit found `DepositStatus
.fromMaturityDate` already a pure function of two dates (no wall-clock read inside it),
already exhaustively tested at exact/day-before/day-after boundaries with zero database and
zero wall-clock dependency, and already correctly independent of `AccountRow.isActive`. The
dashboard's `isAvailable` check and `netWorthSummariesProvider` were confirmed, by reading the
code, to never read `DepositDetails` at all — maturity cannot leak into either total because
neither calculation takes it as an input, not because of any maturity-aware exclusion logic.
Transaction selection was confirmed to be subtype-blind, matching every other account type.

**The one real gap found: Edit Account exposes no deposit fields at all.** This checkpoint
deliberately leaves that gap closed rather than adding partial editing. Every editable
candidate field (interest rate, term, start date, interest method, compounding frequency) feeds
the single stored `maturityDate` and any live `DepositCalculator` estimate a user may have
already seen at creation. This schema has no field-level history/versioning — there is no way
to represent a rate that changed partway through a term, or to safely recompute a previously
shown estimate after the fact. Editing any of these fields would require either inventing such
a versioning mechanism (out of this checkpoint's scope and a genuine architecture decision, not
a UI one) or silently accepting an ambiguous, potentially-misleading result. The existing,
unmodified account-lifecycle path (close the misconfigured deposit, create a correct one) already
handles the realistic failure case — a data-entry mistake — without that ambiguity. This mirrors,
and deliberately contrasts with, ADR-038's Credit Card decision: a credit limit is safe to edit
because it carries no historical-accounting implication, while a deposit's rate/term/start
inescapably does.

**One real defect found and fixed, test-only.** Two widget tests anchored a "still active"
deposit fixture's maturity to a date only a few months past this checkpoint's real-world date
(`startDate: 2026-01-01` + 12 months = `maturityDate: 2027-01-01`) and asserted the rendered
status is "Active" — an assertion that silently expires the moment real time catches up, with
no code change and no warning. Both were moved to a start date decades out (2090) so the
assertion cannot expire within any realistic test-suite lifetime. This is exactly the class of
wall-clock hazard this checkpoint's own brief warns against, found by the audit it required
rather than introduced by this checkpoint.

**Why no `Clock`/time-abstraction class was introduced.** The brief allows "the smallest
testable time abstraction consistent with the existing codebase" if `DateTime.now()` calls
prevent deterministic testing. They do not, and did not before this checkpoint either: this
codebase's one established convention — read `DateTime.now().toUtc()` once at the widget/
provider boundary, pass it into a pure function that takes `now` as an explicit parameter — is
already exactly what `DepositStatus.fromMaturityDate` and its call site do, matching
`budget_providers.dart`/`savings_goal_providers.dart`/`recurring_providers.dart`'s own identical
pattern. Introducing a dedicated `Clock` class for Deposit alone would be a new, inconsistent
abstraction solving a problem the codebase's existing convention already solves.

**Scope of this decision: Deposit maturity/lifecycle audit, test hardening, and the Edit-Account
non-editing decision only.** This ADR does not modify `FinanceEngine`, `DepositDetails`'
schema, any dashboard/net-worth provider, or transaction selection policy — all were confirmed
correct, not changed. See `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.18 for the
full implementation record, including every file changed, test coverage, and the complete list
of legitimate deferrals.
Nothing was staged or committed by this checkpoint.

## ADR-040 — Checkpoint Q: Monthly Budget Progress & Month Navigation is a navigable-month state plus a per-currency summary over already-built primitives

Decision: Checkpoint Q turns the Budgets screen from a current-month-only list into a
navigable, month-oriented dashboard (total/spent/remaining/percentage per currency, plus
per-category progress) by composing primitives ADR-021 had already built, rather than
introducing new financial arithmetic. No schema change (still schema v13). No `FinanceEngine`
change. No change to the Home dashboard's own budget card.

1. **A second, independent month provider — never a replacement for the first one.**
   `currentBudgetMonthProvider` (always the real calendar "now", read by
   `livingCurrencyOverallBudgetProvider` for the Home dashboard's budget card) is completely
   untouched. A new `selectedBudgetMonthProvider` (a `StateProvider<BudgetMonth>`, initialized
   once to the real current month) is the Budgets screen's own single source of truth for
   which month it is showing — both the budget rows listed (`budgetsForSelectedMonthProvider`,
   the navigable counterpart of the now-screen-unused `currentMonthBudgetsProvider`) and the
   spend calculated against them (`budgetMonthSummariesProvider`) watch this one provider.
   Navigating the Budgets screen can never move the dashboard's month, and the dashboard's own
   passage of time can never move the Budgets screen out from under a user who has navigated
   away from the current month — verified by dedicated provider tests
   (`budget_providers_test.dart`, "Checkpoint Q -- selectedBudgetMonthProvider").

2. **`BudgetMonth.previous`/`.next` already were year-boundary-safe and day-of-month-independent
   (see the type's own doc comment, unchanged since ADR-021) — the month-navigation header
   (`_MonthNavigator` on `budgets_screen.dart`) is a thin UI layer over them, writing
   `selectedBudgetMonthProvider`'s state; no new month arithmetic was written.**

3. **Half-open month boundaries reuse the existing inclusive-endpoint convention, not a new
   time convention.** `FinanceEngine._relevant`'s `[fromUtc, toUtc]` filter is inclusive at
   both ends; `BudgetMonth.startUtc`/`.endUtcInclusive` (the last microsecond of the month) are
   already the exact inclusive expression of `[start, nextMonthStart)` that
   `dashboard_providers.dart` established. `budgetMonthSummariesProvider` passes these two
   values unchanged into `FinanceEngine.categoryExpenseTotal` — the same call shape
   `livingCurrencyOverallBudgetProvider` already used for the overall budget's spend. Verified
   for the first/last instant of a month, the following month's first instant, a leap-year
   February, and the December→January boundary
   (`budget_month_summary_test.dart`, "FinanceEngine.categoryExpenseTotal -- half-open month
   boundary").

4. **Category "spent" reuses `FinanceEngine.categoryExpenseTotal` — a primitive ADR-021 already
   built and unit-tested (`finance_engine_test.dart`) but that had no production caller until
   this checkpoint.** It already implements every Section I/J rule this checkpoint needed:
   expense-only (never income, never a transfer), soft-deleted transactions excluded, exact
   category-id matching with no subcategory rollup (`Categories.parentId` remains unpopulated
   and unenforced — ADR-021 point 5, unchanged; a category rename never affects attribution
   because matching is by id). Nothing new was written for this; only a new caller.

5. **One `BudgetMonthSummary` per currency, built only from category budgets — the overall
   budget is deliberately never folded in.** `docs/14_DECISION_LOG.md`'s own ADR-021 (point 13)
   already treats "the overall budget" and "the set of category budgets" as two independent,
   non-overlapping ways to budget the same money, never a hierarchy; summing both into one
   total would double-count capacity that was never meant to stack. A currency with no category
   budget for the selected month simply has no summary — rendered as an explicit, localized
   empty state (`noCategoryBudgetsForMonthMessage`), never a fabricated ¥0 card. Multiple
   currencies never mix into one total (Section O) — verified directly
   (`budget_month_summary_test.dart`, `budget_providers_test.dart`).

6. **`CategoryBudgetProgress` wraps an existing `BudgetCalculation` rather than re-deriving
   budgeted/spent/remaining.** `BudgetCalculator.evaluate` was already generic over "one budget,
   overall or category" — only its inputs differ (`categoryExpenseTotal` instead of
   `incomeExpenseTotals(...).expense`). `usedRatio`/`isOverBudget` are presentation-only
   derived getters on top of it (never persisted, never fed back into any calculation),
   matching `_ConfiguredBudget`'s existing dashboard formula exactly (`spent.minorUnits /
   budgeted.minorUnits`, uncapped).

7. **Percentage text is always the true, uncapped ratio; only a progress bar's fill fraction
   clamps to 1.0.** This was already ADR-021's point 11 for the overall budget — Checkpoint Q
   applies the identical rule to category budgets and the new per-currency month summary,
   reusing the shared `AppProgressBar` primitive (`value: ratio.clamp(0.0, 1.0)`) rather than a
   new hand-rolled bar. A configured budget amount can never be zero (`BudgetRepository`
   rejects it before any write), so this never divides by zero; a `BudgetMonthSummary` is only
   ever constructed for a currency with at least one category budget, so its own `totalBudget`
   can never be zero either.

8. **Overspending is represented in words, never a misleadingly positive "remaining."** When
   `spent > budgeted`/`totalBudget`, the UI shows `l10n.overBudgetByAmountLabel` (e.g. "¥2,500
   over budget") instead of the ordinary remaining-amount label — both the Month Summary card
   and each category's progress details. This is new copy (`overBudgetByAmountLabel`,
   `totalBudgetLabel`, `spentLabel`, `monthSummarySectionTitle`,
   `noCategoryBudgetsForMonthMessage`, `previousMonthTooltip`, `nextMonthTooltip`), added to
   both `app_en.arb`/`app_ja.arb` and hand-synced into the generated localization files (this
   sandbox has no `flutter gen-l10n` toolchain — see the checkpoint's own final report for the
   full validation-gap list). `remainingLabel`/`percentUsedLabel`/`ofAmount` are reused
   unchanged from the existing catalog rather than duplicated.

9. **Add/Edit Budget now read `selectedBudgetMonthProvider`, not `currentBudgetMonthProvider`,
   at submit time — the one genuine behavior change this checkpoint made to existing code.**
   Before this checkpoint, the Budgets screen had no navigation at all, so this distinction was
   invisible; introducing navigation without this fix would have silently created/updated a
   budget for the real current month while the screen displayed a different (historical)
   month's list — exactly the Section K hazard the checkpoint brief called out by name. Fixed
   in both `_OverallBudgetDialogState._submit` and `_CategoryBudgetDialogState._submit`;
   verified directly (`budgets_screen_test.dart`, "Checkpoint Q -- Add/Edit Budget respect the
   selected historical month").

10. **Month navigation is arrow buttons only — no `PageView`/swipe.** The codebase has no
    existing swipe-driven navigation pattern to extend, and the checkpoint brief explicitly
    treats a fragile infinite `PageView` merely to satisfy "slide" as out of scope, ranking
    correct prev/next arithmetic above the gesture. This is a legitimate, documented deferral,
    not an oversight.

**Scope of this decision.** This ADR covers the selected-month provider, the half-open month
interval, the category/month spend and percentage semantics, the currency-scoped summary, the
Add/Edit historical-month fix, and the new localization keys. It does not touch
`FinanceEngine`, the `budgets` table schema, `BudgetCalculator`/`BudgetStatus` (the existing
pace-based status these already compute remains a separate, still-unused-by-this-screen
concept from the raw percentage-of-budget-used this checkpoint displays), the Home dashboard's
budget card, or any other checkpoint's regression boundary (Savings, Deposit, Credit Card,
cheques, Net Worth, KakeiboPlus branding) — all confirmed unaffected by inspection, since none
of those areas' files were touched.

## ADR-041 — Checkpoint R: Budget experience completion is an audit-and-harden pass over ADR-040's architecture, not a new one; V1 has no rollover

Decision: Checkpoint R is the acceptance/completion checkpoint for the month-based Budget
experience ADR-040 built. The audit found ADR-040's architecture already correct and complete
for nearly every requirement in the checkpoint brief; R's actual changes are two explicit
regression tests proving a policy that was already true by construction, plus targeted widget
tests for category/month states the existing test suite had not yet exercised directly. No
production behavior changed. No schema change (still schema v13). No `FinanceEngine` change.

1. **Selected month remains the Budget screen's single presentation context, unchanged from
   ADR-040.** `selectedBudgetMonthProvider` still drives `budgetsForSelectedMonthProvider` and
   `budgetMonthSummariesProvider` exclusively; `currentBudgetMonthProvider` (the Home
   dashboard's real-"now" budget card) remains untouched and independent. Every value on the
   Budgets screen — total budget, spent, remaining/over-budget, percentage, progress bars,
   category rows, empty states, and the Add/Edit dialogs' target month — is derived from
   whichever `BudgetMonth` is currently selected, never from `DateTime.now()` directly. This
   was already fully true and tested under ADR-040; R only re-confirms it and adds the
   remaining scenario coverage below.

2. **Month/category progress formulas are unchanged:** `totalBudget = Σ active category
   budgets for the selected currency/month`; `spent = Σ FinanceEngine.categoryExpenseTotal`
   per budgeted category (expense-only, soft-deletes excluded, exact category-id match);
   `remaining = totalBudget - spent` (can be negative); `usedRatio = spent / totalBudget`,
   uncapped in text; `isOverBudget = spent > totalBudget` (strict). The "exactly used" case
   (`spent == totalBudget`) therefore falls out of `isOverBudget` correctly on its own —
   `remaining` is `0`, `usedRatio` is `1.0`, and the UI takes the ordinary (non-over-budget)
   `_StatRow` branch, showing "100% used" and a plain "¥0" remaining figure rather than "over
   budget by ¥0". This was already correct in the existing formula (no code changed); R adds
   `budgets_screen_test.dart`'s "an exactly-used month shows 100% and zero remaining..." and "a
   category spent exactly its budget shows 100% used..." tests, since no prior test exercised
   this exact boundary at either the month or category level.

3. **Displayed percentage above 100% and clamped visual progress are unchanged.** Text is
   always the true, uncapped `usedRatio * 100` (e.g. "125% used"); only
   `AppProgressBar`/`LinearProgressIndicator`'s fill fraction clamps to `[0.0, 1.0]`
   (`summary.usedRatio.clamp(0.0, 1.0)` / `progress.usedRatio.clamp(0.0, 1.0)`), and the
   over-budget amount is always stated explicitly in words
   (`l10n.overBudgetByAmountLabel`), never disguised as a positive "remaining". R adds explicit
   category-level 0%/100%/>100% widget tests alongside the month-level test ADR-040 already
   had, closing the only genuinely missing widget coverage the audit found.

4. **Zero-budget vs. no-budget remains an enforced invariant, not a new decision.**
   `BudgetRepository._validateAmount` (`InvalidBudgetAmountException`, already tested in
   `budget_repository_test.dart` before ADR-021) rejects a zero or negative amount before any
   write, so a persisted budget row is always strictly positive — "budget configured as zero"
   is not a state the schema can express. "No budget configured" is simply the absence of an
   active row for that profile/currency/year/month(/category), rendered as the existing
   localized empty states (`noBudgetsSetThisMonthMessage`, `noCategoryBudgetsForMonthMessage`),
   never a fabricated ¥0 card. `BudgetMonthSummary.usedRatio`/`CategoryBudgetProgress.usedRatio`
   can therefore never divide by zero, by construction of the persistence layer they're built
   from.

5. **V1 explicit no-rollover policy — audited, confirmed absent, and now regression-tested.**
   A full-codebase search (`lib/`, `test/`, `docs/`) for rollover/carry-forward/carried-balance/
   automatic-budget-generation concepts found no such implementation anywhere in production
   code or tests. Every hit was either an unrelated feature already documenting its own "no
   rollover" stance (`deposit_status.dart`'s deposit renewal) or an existing document already
   recording rollover as explicitly out of scope for Beta 1/V1
   (`docs/00_MASTER_BLUEPRINT.md`, `docs/03_DATABASE_SCHEMA.md`'s `rollover_enabled` listed as
   an out-of-scope column, `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md`'s "No rollover...",
   `lib/features/budgets/README.md`'s "recurring/rollover budgets... out of scope"). No
   conflicting rollover model exists to report or reconcile. `BudgetMonthSummary` is built
   exclusively from the selected month's own category-budget rows and the selected month's own
   `categoryExpenseTotal` window — it has no field, parameter, or code path that reads any
   other month's remaining or overspent figure, so no rollover can occur by construction. R
   makes this an explicit regression rather than an implicit property: two new
   `budget_providers_test.dart` tests ("an unused remainder in one month never increases the
   following month's total budget" / "overspending in one month never reduces the following
   month's total budget") seed August with a real unused remainder and a real overspend
   respectively, then assert September's `totalBudget` is exactly the amount configured for
   September — never adjusted by August's leftover or shortfall.

6. **Month isolation, currency isolation, and the historical-month Add/Edit fix all remain
   exactly as ADR-040 left them** — verified by inspection and by the pre-existing, still-
   passing `budgets_screen_test.dart` groups ("budgets never leak across months", "Add/Edit
   Budget respect the selected historical month"), unchanged by this checkpoint.

7. **Why these remain derived, not persisted:** `remaining`, `usedRatio`, `isOverBudget`, and
   every percentage/progress value continue to be pure functions of persisted budget rows and
   persisted transactions, recomputed on read — never written back to the database. This keeps
   the no-rollover policy trivially true (there is no stored "remaining" value for a rollover
   calculation to ever read) and keeps `FinanceEngine` and the ledger completely unaware that
   budgets exist, matching Section P/O of the checkpoint brief.

8. **Credit Card (Checkpoint O), Deposit (P), Cheques (N), Net Worth, Home, and KakeiboPlus
   branding are all unaffected** — none of their files were touched by this checkpoint; the
   only files changed are `test/features/budgets/presentation/budget_providers_test.dart` and
   `test/widget/budgets_screen_test.dart` (new test coverage) and this decision log entry. No
   production file changed.

## ADR-042 — Checkpoint S: Savings Goals completion is a hardening pass over ADR-022's architecture, plus one genuine double-submit fix

Decision: Checkpoint S audited the existing savings-goals feature
(schema version 3, ADR-022) against a 55-item completion checklist and
found the architecture itself already correct end to end. This entry
records that audit's findings, the one real production defect it
surfaced and fixed, the regression coverage added to actually prove the
contract rather than merely assert it in a doc comment, and one
deliberate deferral.

1. **Persistence model is unchanged; no migration.** `savings_goals`/
   `savings_goal_contributions` were introduced correctly at schema
   version 3 and the app is at schema version 13 today — no legacy
   pre-v3 goals data exists to migrate, `SavingsGoalRepository`
   validates every write before it reaches the table (rejecting a
   non-positive target/contribution amount, per ADR-022), and no
   import/bulk-write feature exists that could bypass that validation.
   A target of zero or less is therefore not representable through any
   current production code path; the pure `evaluateSavingsGoalStatus`
   function's deliberate `throw ArgumentError` for that input (already
   tested in `savings_goal_status_test.dart`) is the correct contract
   for an invariant that should never actually be reachable, not a
   robustness gap to work around with new defensive machinery.

2. **The one genuine production defect: a double-submit re-entrancy
   gap in all three savings-goal dialogs.** `_AddContributionDialogState
   ._submit`, `_EditGoalDialogState._submit`
   (`goal_detail_screen.dart`), and `_CreateGoalDialogState._submit`
   (`savings_goals_screen.dart`) each disable their Save button via
   `onPressed: _isSaving ? null : _submit`, but `setState` only takes
   effect on Flutter's NEXT rendered frame — it does not retroactively
   block a second tap that lands before that frame renders. Two
   `onPressed` invocations arriving before any rebuild (a real
   double-tap, or a slow/busy device) both ran `_submit`'s full body,
   including the second, un-guarded call to `addContribution`/
   `createGoal`/`updateGoal`. The fix is the smallest possible
   correction: `if (_isSaving) return;` as the very first line of each
   `_submit`, so a re-entrant call is a no-op regardless of whether a
   rebuild has happened yet.

   **Test-technique correction (post-Checkpoint-S-report Windows
   validation):** the first draft of this coverage modeled the
   re-entrancy by calling `tester.tap` twice on the same `Finder` with
   no `pump()`/`pumpAndSettle()` between the calls. A real `flutter
   test` run caught this as a potential false positive: `tester.tap`'s
   own gesture-dispatch code (`TestAsyncUtils.guard`/`startGesture`/
   `gesture.up()`) contains genuine `await` points, and Dart yields to
   the microtask queue at every `await` — even one that resolves
   immediately. That is enough for the FIRST tap's pending `await
   addContribution(...)`/`createGoal(...)` (a plain `Future`, not the
   Timer-based Drift stream watches documented elsewhere in this
   project, so no `pump()` is needed for it to progress) to complete and
   pop the dialog before the SECOND tap's hit-test ever runs — Flutter
   then correctly warns that the second tap's precomputed offset no
   longer lands on the (now closing/gone) `FilledButton`. Had that
   happened, "only one row written" would have been true for an
   uninteresting reason (the second tap hit nothing) rather than because
   `_isSaving` intercepted a genuine second concurrent submit.

   The corrected technique fetches the CURRENT `FilledButton` widget
   once via `tester.widget<FilledButton>(...)` and invokes its real
   `onPressed` callback — the actual `_submit` closure each dialog's
   `build` wired up — twice in a row with no `await` between the two
   calls; two back-to-back synchronous statements never yield to the
   microtask queue, so this deterministically fires `_submit()` twice
   before either call's own `await` can resolve, without any gesture/
   hit-testing involved and without a test-only production seam. Three
   tests now use this technique, one per guarded dialog: "rapid
   double-tap on Add Contribution's save button" and "the same
   re-entrancy guard on Edit Goal's save button" in
   `goal_detail_screen_test.dart`, and "two rapid submit attempts when
   creating a goal" in `savings_goals_screen_test.dart` — each asserting
   exactly one row was written (or, for Edit Goal, exactly one update
   applied), not two.

3. **Contribution ledger weight: zero, confirmed end to end, not just
   by inspection.** ADR-022 already established that a contribution
   creates no `Transactions` row; this checkpoint additionally proved,
   with a new regression test
   (`savings_goal_contribution_repository_test.dart`, "Checkpoint S:
   zero ledger weight"), that adding AND deleting a contribution never
   changes `FinanceEngine.accountBalance`'s result for a real account —
   computed from that account plus whatever the real ledger actually
   contains, before and after, not a value re-derived from the
   contribution data itself. A goal's target/remaining/percentage/
   completion state have the same zero ledger weight by construction:
   none of `savings_goal_calculation.dart`, `savings_goal_status.dart`,
   or `savings_goal_providers.dart` reference `FinanceEngine`, any
   account, or any transaction at all — confirmed by a full-codebase
   search finding no such reference anywhere. Home's priority-goal card
   reads `homeGoalSelectionProvider` purely for display and never feeds
   into the dashboard's Net Worth/Available Money figures, which remain
   computed exclusively from `FinanceEngine`.

4. **Derived completion already produces the right answer for every
   target-edit direction; only the regression tests were missing.**
   Because `SavingsGoalCalculator.evaluate` always recomputes `status`
   fresh from the CURRENT `target`/`saved` (never a persisted flag),
   lowering a goal's target below its already-contributed amount
   correctly completes the goal (remaining becomes zero, the real
   contribution amount is preserved untouched, `wholePercentSaved`
   reads the true uncapped figure, e.g. 180%) with no code change
   needed, and raising a completed goal's target back above its saved
   amount correctly returns it to `inProgress` the same way. Deleting a
   contribution that had completed a goal correctly returns it to
   `inProgress` for the identical reason. All three are now explicit
   regression tests in `savings_goal_providers_test.dart` (previously
   untested at any layer, despite the architecture already being
   correct).

5. **Widget-level coverage gap: Overdue/Completed/>100% states, target
   date, recommended-daily-contribution, and milestone chips had zero
   test coverage.** Neither `goal_detail_screen_test.dart` nor
   `savings_goals_screen_test.dart` contained a single assertion on the
   "Overdue" or "Completed" status label, the milestone chips'
   reached-vs-not-reached visual state, the target-date/recommended-
   daily-contribution detail rows rendering, or the >100% uncapped
   percentage text before this checkpoint — despite all of that being
   correctly implemented already. Six new widget tests close this gap
   in `goal_detail_screen_test.dart`'s new "Checkpoint S" group. One
   test-writing note worth recording: a completed goal's "recommended
   daily contribution" is ALSO a real `Money.zero` (ADR-022 point 2 —
   completed always answers zero, never null, regardless of target
   date), so asserting the Remaining row's "¥0" text requires scoping
   to that row's own `Row` ancestor (`find.ancestor(...).first` +
   `find.descendant`) rather than a bare `find.text('¥0')`, which would
   otherwise match both rows.

6. **Goal creation/editing validation, currency anchoring, target-date
   normalization, milestone overflow-safety, and soft-delete
   invariants were all re-audited and found unchanged and correctly
   tested already (ADR-022 points 1, 3, 4, 5, 6, 8).** No code or test
   changes were needed for any of these; this checkpoint did not touch
   `savings_goal_calculation.dart`, `savings_goal_status.dart`,
   `savings_goal_milestones.dart`, `goal_target_date.dart`,
   `savings_goal_repository.dart`, or
   `savings_goal_contribution_repository.dart` at all.

7. **Deliberately deferred: the pre-existing Riverpod `.stream`
   deprecation info inside `savings_goal_providers.dart`.**
   `_activeContributionsProvider` builds its reactive aggregate via
   `ref.watch(_activeGoalRowsProvider.stream).asyncExpand(...)` —
   `StreamProvider.stream` has carried a Riverpod deprecation notice
   since well before this project's pinned `flutter_riverpod: ^2.6.1`
   (recommending `ref.listen` for the simple "subscribe and react"
   case). That recommended replacement does not cover this file's
   actual use, which is combining/re-subscribing an INNER stream
   whenever an OUTER one changes (a live re-`asyncExpand`), not a
   simple listen-and-react; Riverpod's own maintainer treats that
   specific stream-combinator case as still lacking a clean built-in
   replacement as of this writing. Rewriting it without one would mean
   inventing new state-management machinery for an already-correct,
   already load-bearing, extensively-tested reactive aggregation this
   checkpoint has no mandate to redesign — exactly the "requires
   unrelated architectural churn" case Checkpoint S's brief says to
   document and defer rather than fix. Left exactly as before,
   alongside the other pre-existing `.stream` info in
   `app_router.dart` (routing, out of this checkpoint's scope
   regardless).

8. **`lib/features/goals/README.md` was stale and has been corrected.**
   It previously read "Not implemented yet," left over from before
   ADR-022 shipped the feature; it now points at ADR-022 and this entry
   and briefly explains why `savings_streaks`/`savings_milestones` from
   `docs/03_DATABASE_SCHEMA.md` were never added as separate tables
   (milestone attainment is derived, not persisted or streak-tracked, in
   Beta 1's scope).

9. **Budgets (Checkpoint R/ADR-041), accounts, transactions, Net Worth,
   Home's privacy boundary, routing, and every other feature are
   unaffected** — the only production files this checkpoint changed are
   `lib/features/goals/presentation/goal_detail_screen.dart`,
   `lib/features/goals/presentation/savings_goals_screen.dart` (the
   double-submit guard, both trivial one-line additions plus a comment),
   and `lib/features/goals/README.md` (documentation only).

## ADR-043 — Checkpoint T: Recurring Transactions completion is an audit-and-harden pass over ADR-023/ADR-024's architecture, plus two genuine double-submit fixes

Decision: Checkpoint T audited the existing recurring-transactions
feature (schema version 13; `RecurringRules`/`RecurringOccurrences`
introduced at ADR-023 in Beta 1 Task 4A, reminder notifications added at
ADR-024, the Recurring + Subscriptions V1 estimate work at ADR-031)
against a 70-item completion checklist and found the architecture
itself already correct end to end, including durable duplicate-post
protection. This entry records that audit's findings, the two genuine
UI production defects it surfaced and fixed, and the regression
coverage added to prove invariants the existing test suite asserted in
doc comments but had not yet exercised with a genuine concurrency test.

1. **Persistence model is unchanged; no migration.** `RecurringRules`
   (schedule/template: kind, name, amount/currency, account/destination
   account, category, note, frequency/interval/startDate/endDate,
   `notificationsEnabled`, soft delete) and `RecurringOccurrences` (one
   row per *handled* — posted or skipped — `(ruleId, scheduledDate)`
   pair; a due-but-unhandled date is never persisted, only derived) were
   introduced correctly at schema version 13 and the app is still at
   schema version 13 today. No new column or table was required.

2. **Supported transaction kinds and recurrence frequencies are wider
   than this checkpoint's brief assumed.** Recurring rules already
   support expense, income, AND same-currency transfer (`RecurringRuleKind`)
   — a cross-currency recurring transfer is rejected the same way
   `TransactionRepository.recordTransfer` rejects one manually (ADR-019).
   Supported frequencies are daily/weekly/monthly/yearly, each with an
   arbitrary `interval >= 1` (e.g. "every 3 weeks"). Both are already
   fully implemented and tested; neither needed to be added.

3. **Calendar/month-end semantics are already correct and shared with
   one other feature.** `RecurringSchedule` (`recurring_schedule.dart`)
   computes every occurrence directly from the rule's `startDate` anchor
   — never by adding one period to the previous occurrence — specifically
   so a schedule anchored on the 31st clamps independently against each
   target month's actual length (Jan 31 → Feb 28/29 → Mar 31 → Apr 30 …)
   instead of drifting to the 28th permanently. The month/year clamping
   arithmetic itself lives in one shared, already-reused routine,
   `lib/core/finance/calendar_month_math.dart`'s `addWholeCalendarMonths`
   (also used by Checkpoint F's deposit maturity-date math) — there is
   exactly one such implementation in the codebase, not two that could
   silently drift apart. `startDate`/`endDate`/`scheduledDate` are all
   calendar-only UTC-midnight dates (`normalizeRecurringDate`), never
   genuine instants — the same "never `.toUtc()` a picked local date"
   discipline `SavingsGoals.targetDate` established.

4. **Posting/skipping already goes through the canonical transaction
   path — no second ledger.** `RecurringOccurrenceRepository
   .postOccurrence` calls the exact same `TransactionRepository
   .recordExpense`/`.recordIncome`/`.recordTransfer` the manual Add
   Transaction screen calls — proven directly (not merely asserted) by
   this checkpoint's new "a posted recurring expense/income changes the
   account balance by exactly its amount" tests, which run the posted
   occurrence through `FinanceEngine.accountBalance` the same way
   Checkpoint S's savings-goal ledger-weight test did. `skipOccurrence`
   creates no `Transactions` row at all — also newly proven directly
   (account balance before/after a skip is bit-for-bit identical, and
   the transactions table stays empty). Downstream consumers (account
   balances, income/expense totals, budget "spent" figures) are
   generic queries over `Transactions`/`LedgerTransaction` with no
   recurring-specific branch anywhere, so they see a posted occurrence's
   transaction exactly as they would a manually entered one, by
   construction — no dedicated recurring-vs-budget integration test was
   added, since it would only re-prove the budget feature's own
   already-tested generic category-sum logic against a different
   transaction source.

5. **Duplicate-post protection is durable, not merely a UI guard, and
   this checkpoint proved the concurrent case the existing tests had
   not.** At most one `RecurringOccurrences` row may exist per
   `(ruleId, scheduledDate)` pair, enforced at the application layer:
   both `postOccurrence` and `skipOccurrence` check for ANY existing
   handled row for that pair before writing, AND re-check a second time
   *inside* the same `AppDatabase.transaction()` block that performs the
   actual write — the real ledger transaction and the occurrence row are
   written atomically together. The existing test suite already proved
   this holds when the same occurrence is posted/skipped **sequentially**
   (`recurring_occurrence_repository_test.dart`'s "handled-occurrence
   uniqueness" group predates this checkpoint). It had not proved the
   race matters most: two truly **concurrent**, unawaited calls. This
   checkpoint added that test — firing two `postOccurrence` calls
   together via `Future.wait` with no sequential `await` between them —
   and it passes: because Drift/SQLite serializes transaction bodies on
   the single connection, the second call's in-transaction re-check
   always observes the first call's already-committed row, so exactly
   one transaction and one occurrence row are ever created, never two
   and never zero. A second new test proves the mixed post-vs-skip race
   the same way: a single occurrence is never both posted and skipped.

6. **Two genuine UI production defects: the same double-submit
   re-entrancy gap ADR-042 fixed for the savings-goal dialogs, present
   here too.** `_RuleDialogState._submit` (create/edit a rule) and
   `_PendingItemTileState._handle` (post/skip/edit/delete a pending
   item) each disable their button via `onPressed: _isSaving ? null :
   ...` / `onPressed: _isBusy ? null : ...`, but neither method itself
   checked that flag before doing its work — `setState` only takes
   effect on Flutter's next rendered frame, so a second `onPressed`
   invocation landing before that frame renders ran the full method body
   again regardless. For `_RuleDialogState._submit`, this is a genuine
   financial-data-integrity gap: `RecurringRuleRepository.createRule`/
   `.updateRule` have no natural uniqueness key to reject a duplicate
   call with, so two concurrent Saves really would create two separate
   recurring rules (or apply the same edit twice). For
   `_PendingItemTileState._handle`, item 5 above already means a second
   concurrent post/skip could never create a duplicate financial
   transaction — but without a guard it would reach `postOccurrence`/
   `skipOccurrence` a second time, get rejected with
   `RecurringOccurrenceAlreadyHandledException`, and surface a confusing
   error snackbar for an action the user only meant to perform once. The
   fix is the same one-line pattern both times: `if (_isSaving) return;`
   / `if (_isBusy) return;` as the very first line of each method.

7. **Test technique for both fixes follows the corrected (not the
   originally-flawed) Checkpoint S technique from the start.** Two
   physical `tester.tap()` calls risk the exact false positive
   documented in ADR-042's own test-technique correction (a tap's
   internal `await`s can let the first call's `_submit`/`_handle` run to
   completion and pop/rebuild before the second tap's hit-test executes,
   making "only one write happened" true because the second tap missed,
   not because a guard worked). Both new widget tests instead fetch the
   current `FilledButton` once and invoke its real `onPressed` callback
   twice with no `await` between the calls — exercising the actual
   production closure deterministically, with no gesture/hit-testing
   involved and no test-only seam.

8. **Overdue policy: multiple missed periods are deliberately
   represented, not collapsed to one.** `_pendingItemsForRule`
   (`recurring_providers.dart`) surfaces every unhandled occurrence
   between a rule's `startDate` and today as a separate, individually
   addressable pending item (each with its own `scheduledDateUtc`
   identity) — a rule overdue for three periods shows three cards, not
   one. This is bounded (never infinite): the overdue/due-today range is
   inherently capped at "today", and the separate forward-looking
   "upcoming preview" (shown only once a rule has nothing unhandled on
   or before today) is walked via `RecurringSchedule.nextOccurrenceAfter`
   with a defensive 10,000-iteration cap against a pathological
   never-ending schedule. This was already implemented and already
   documented in the source; this checkpoint did not change it.

9. **Generated-transaction edit/delete interaction was ambiguous only
   in the sense of "untested", not "undecided" — this checkpoint added
   the missing proof.** Two new tests establish, directly: (a) deleting
   (soft-deleting) the `Transactions` row a posted occurrence generated
   leaves that `RecurringOccurrences` row permanently `'posted'` — there
   is no reconciliation code path that frees the occurrence up, so it
   can never be re-posted or re-skipped through stale state; and (b)
   editing that generated transaction's fields directly is never
   overwritten by later editing or soft-deleting the recurring rule —
   `RecurringRuleRepository` has no rule-to-transaction sync/
   re-derivation path at all, by design (its own doc comment already
   said so; this proves it).

10. **Account/category lifecycle is already handled correctly.**
    `AccountLifecycleService.closeAccount` calls `RecurringRuleRepository
    .activeRulesReferencingAccountOnce` and blocks the close entirely if
    any active rule (as source or transfer destination) references that
    account — a recurring rule can never be left pointing at a closed
    account and silently post invalid ledger activity. Categories have
    no delete path anywhere in this codebase (`CategoryRepository` has
    no delete/soft-delete method at all), so a recurring rule's
    `categoryId` can never dangle — item 42 is not applicable to this
    V1 architecture, not an unhandled case.

11. **Currency/minor-unit invariants are unchanged and already
    enforced.** `RecurringRuleRepository._validateAccounts` enforces the
    rule's currency matches its account(s)' currency for every kind, and
    rejects a cross-currency transfer, before any row is written — no
    hidden conversion exists anywhere in this feature. All amounts are
    integer minor units throughout; nothing in this checkpoint touched
    money representation.

12. **Deliberately deferred / out of scope (per the checkpoint's own
    non-goals and this audit's findings):** bank sync, automatic
    background posting, calendar integration, an RRULE editor, AI
    rule generation, split/family recurring rules, and the app-wide
    icon/color visual identity system — none of these exist today and
    none were added. The pre-existing Riverpod `.stream` deprecation
    infos in `app_router.dart`/`savings_goal_providers.dart` were left
    untouched, as instructed.

**Files changed:** `lib/features/recurring/presentation/recurring_screen.dart`
(the two one-line re-entrancy guards, each with an explanatory comment);
`test/core/database/repositories/recurring_occurrence_repository_test.dart`
(seven new tests: two genuine concurrency races, two account-balance
ledger-impact proofs, one skip-zero-ledger-effect proof, and two
generated-transaction edit/delete interaction tests);
`test/widget/recurring_screen_test.dart` (two new widget-level
re-entrancy tests). No other production file changed; no
migration; no localization change (no new user-visible string was
introduced).

## ADR-044 — Checkpoint U1: Category, Service, Currency & Card Visual Identity Foundation is built almost entirely on architecture that already existed; the ONE genuine gap was category color

Decision: Checkpoint U1's own mandatory pre-implementation audit (its
brief's section 3, 20 items) found that most of the "foundation" it
asked for was already in place -- `categories.icon` already persisted
and already had a resolver (`categoryIconFor`, ADR-025/026);
`payment_instruments.network` already persisted a full `CardNetwork`
enum with a create/edit dropdown and complete localization
(`add_account_form_screen.dart`); a shared, size-tiered, theme-driven
icon-tile primitive (`AppIconTile`) already existed (Checkpoint 10). No
category COLOR mechanism existed anywhere, and no screen rendered a
category's icon+color consistently (several independently re-resolved
it, several didn't render it at all). This entry records what the audit
found already correct, the one schema change it made, and every new
architectural piece built on top.

1. **Stable identifiers, never volatile ones -- audited, not just
   asserted.** `categories.icon` (a `Categories.icon` semantic key
   string) and `payment_instruments.network` (a `CardNetwork
   .storageValue` string) already followed this checkpoint's own
   non-negotiable principle before this checkpoint began. The new
   `categories.color_key` column (below) and the new `CategoryColorKey`/
   `ServiceIdentityKey` enums follow the exact same "named string, never
   an index/codepoint/theme-derived value" convention.

2. **The one genuine schema change: `categories.color_key`.** Schema
   version 13 -> 14 adds one nullable `TextColumn` to `categories` --
   see `app_database.dart`'s own migration-step doc comment for the
   full `from < 14` rationale, and `tables.dart`'s `Categories.colorKey`
   doc comment. The 8 fixed-id seeded system categories are backfilled
   to a deterministic color each (both via the migration's frozen
   literals, for an upgrading install, and via `CategoryRepository
   ._systemCategories`' own new `colorKey` field, for a fresh install --
   the two lists are kept in sync by hand, matching the "frozen literal,
   not computed from a live enum" discipline every migration in this
   codebase already follows). Every other pre-existing category is left
   `color_key = null` -- deliberately not backfilled, because
   `categoryColorFor` already resolves `null` to a deterministic,
   stable-per-category-id fallback color at read time
   (`lib/features/categories/domain/category_color.dart`), so a legacy
   category never looks random or flickers between sessions without
   needing a backfill statement for every row.

3. **One authoritative resolver, reused everywhere, not duplicated per
   screen.** `CategoryIdentityIcon`
   (`lib/features/categories/presentation/category_identity_icon.dart`)
   is the ONE widget that resolves a category's `icon`/`colorKey`
   together into a rendered tile, built on the pre-existing `AppIconTile`
   primitive rather than inventing a new container shape. It is now used
   by: the Categories screen's own list (which previously rendered no
   icon at all), the Add/Edit Transaction category dropdown, the
   Recurring rule dialog's category dropdown, and the category-budget
   tile on the Budgets screen (which previously showed a single fixed
   generic icon regardless of category). `category_identity_icon_test
   .dart` proves the specific property the brief asked for directly: the
   same `(categoryId, iconKey, colorKey)` renders an identical `Icon`
   (same `IconData`, same `Color`) inside two structurally different
   surrounding widget trees.

4. **Category icon catalog expanded from 8 to 50 curated concepts, one
   map, never forked.** `category_icon.dart`'s `_categoryIconsByName`
   is still the single source of truth `categoryIconFor` resolves
   against; it grew from the original 8 system-category seed icons
   (kept byte-for-byte unchanged) to 50 entries spanning Food & Dining,
   Shopping, Transport, Housing & Bills, Health & Personal Care,
   Entertainment, Education, Family & Pets, Travel, Finance/Fees/
   Insurance, Gifts, Subscriptions/Digital Services, Income, and
   Miscellaneous. `categoryIconKeys` (a new, ordered, read-only view
   over that same map's keys) is what the new icon picker iterates --
   there is no second, independently-maintained key list anywhere.
   Localized picker labels for all 50 live in a deliberately separate
   file, `category_icon_catalog.dart`, so `category_icon.dart` itself
   keeps its pre-existing "pure, no `BuildContext`" contract.

5. **A new curated, accessible, light+dark-safe category color palette
   -- 14 named colors, independent of icon choice.** `CategoryColorKey`
   (`category_color.dart`) is a small, explicit enum, each with its own
   light-theme and dark-theme `Color`, chosen from the Material 3 tonal
   palette family for comparable contrast/vibrancy in both themes at the
   same 0.14-alpha tint `AppIconTile` already uses. `resolveCategoryColorKey`
   /`categoryColorFor` never throw for `null` or an unrecognized stored
   value -- see item 2 above for the deterministic-fallback rationale.

6. **User-facing category customization: icon + color pickers, plus a
   genuinely new edit flow.** The pre-checkpoint audit found
   `CategoriesScreen`'s Add dialog only ever collected a name --
   `CategoryRepository` had no `updateCategory` method at all, and no
   screen offered to edit an existing category's icon/color (or, for a
   non-system category, its name). This checkpoint added both: the Add
   dialog now also offers `CategoryIconPicker`/`CategoryColorPicker` (a
   bounded-height scrollable icon grid; a color swatch row), and a new
   Edit dialog reachable from each row's new edit `IconButton`. Both
   pickers mirror `theme_customization_screen.dart`'s pre-existing
   `_ThemeSwatchCard` accessibility convention exactly -- selection is
   communicated through a colored border, a check-mark badge, AND a
   `Semantics.selected`/announced-suffix label, never color alone --
   rather than inventing a new pattern. A system category's name field
   is deliberately omitted from the Edit dialog (preserving this
   codebase's pre-existing "Beta 0 has no UI to rename the system set"
   boundary) while its icon/color remain fully editable, since both are
   presentation metadata only and never affect `FinanceEngine`/any
   balance, budget, or goal calculation. Per the brief's own V1 scope,
   "custom icon" means choosing from this curated catalog -- no
   arbitrary uploaded image/SVG icon support was added.

7. **Card network identity: already a complete, working feature; this
   checkpoint added only the shared display widget.** The audit found
   `payment_instruments.network` (a nullable `CardNetwork.storageValue`
   column), the `CardNetwork` enum itself (visa/mastercard/jcb/amex/
   other), and a fully localized create/edit dropdown
   (`add_account_form_screen.dart`) already shipped and working -- no
   migration, no new persistence, nothing to fix. The one real gap was
   a shared, reusable DISPLAY component: `CardNetworkBadge`
   (`lib/shared/widgets/card_network_badge.dart`) renders the network's
   plain localized NAME as a small pill (reusing `AppStatusChip`
   directly, and reusing the exact same `addAccountCardNetwork*` ARB
   strings the dropdown already used -- no second, divergent copy of
   those four/five names), deliberately never a recreated brand logo --
   see item 9 below for why that choice was made deliberately, not out
   of laziness. Adopted as a live selection preview next to the
   create/edit dropdown itself, since the audit also found there is
   currently no dedicated "view a saved payment instrument" screen
   anywhere in the app at all -- building one was out of scope for this
   checkpoint (it is not a visual-identity gap; it is a pre-existing,
   separate missing-screen gap), so the badge is proven in the one
   existing screen that already handles card network.

8. **Currency identity: code stays authoritative; region indicator is
   new, optional, deliberately not one-currency-one-country.**
   `CurrencyBadge` (`lib/shared/widgets/currency_badge.dart`) always
   renders the ISO 4217 code verbatim; an opt-in `showRegionIndicator`
   adds a small, secondary, muted two-letter monogram -- deliberately
   NOT an emoji flag (the brief's own audit concern: inconsistent emoji
   rendering across platforms/fonts, confirmed by this codebase having
   zero pre-existing flag usage anywhere to build on) and never a
   downloaded/remote image, so the badge is fully offline and renders
   identically everywhere. EUR resolves to the neutral 'EU' monogram,
   never an arbitrarily-chosen single Eurozone country -- the one
   multi-region case the brief called out by name. A currency code with
   no deliberate entry in the small, explicit glyph map (anything
   outside this Beta's 13-currency `CurrencyRegistry` seed) simply shows
   no glyph at all rather than guessing. Adopted at the two currency
   *selector* dropdowns that existed before this checkpoint and
   previously showed only a bare code `Text` -- the Add Account currency
   picker and the Create Savings Goal target-currency picker -- per the
   brief's own "avoid duplicating the same flag/code six times inside
   one card" guidance, this checkpoint did not mechanically stamp the
   badge onto every money-showing surface in the app.

9. **Service/subscription identity: a real, separate architecture,
   deliberately using generic family icons instead of brand logos.**
   `ServiceIdentityKey`
   (`lib/features/services/domain/service_identity.dart`) is a small,
   explicit enum of service FAMILIES (streaming video, music, cloud
   storage, AI/software, productivity, gaming, other) -- category
   ("Entertainment") and service ("Netflix") are kept as two separate
   catalogs, per the brief's own requirement, but this checkpoint has no
   licensed brand-asset source available to it, and the brief itself
   permits (and, without one, requires) falling back to "a neutral
   service identity" rather than fabricating a trademark approximation,
   recoloring a real logo, or depending on a remote logo URL. Each
   family resolves to a generic, unbranded Material icon and reuses
   `CategoryColorKey`'s existing palette (never a second color system).
   `ServiceIdentityIcon` renders it through the same `AppIconTile`
   primitive. Not wired into any screen: the audit found no existing
   service/subscription selection UI or persisted field anywhere in
   this codebase to attach it to, and adding one preemptively would
   violate this checkpoint's own (and every prior checkpoint's) "audit
   before adding persistence" discipline. A future checkpoint with an
   actual service-selection UI, or a licensed brand-asset source, can
   extend this enum/catalog without changing its call sites.

10. **Never throws, anywhere in this system.** `categoryIconFor`
    (pre-existing), `categoryColorFor`/`resolveCategoryColorKey`,
    `categoryIconLabel`, `ServiceIdentityKey.fromStorageValue`/
    `serviceIdentityIconFor`/`serviceIdentityColorFor`, and
    `CardNetworkBadge`'s network-to-label mapping all resolve `null` or
    any unrecognized value to a deterministic, real fallback rather than
    throwing or rendering blank -- exercised directly by this
    checkpoint's new unit tests for each function, not merely asserted
    in a doc comment.

11. **No financial calculation touched.** Every new/changed column,
    resolver, and widget in this checkpoint is presentation metadata
    only. `FinanceEngine`, every balance/budget/goal/recurring-posting
    calculation, and every existing currency-arithmetic path are
    completely untouched -- this checkpoint added a `SELECT`able
    `color_key` column and read-only resolvers/widgets, nothing that any
    financial calculation reads.

12. **Deliberately deferred / out of scope, per the brief's own
    non-goals and this audit's findings:** Dashboard/Home visual-
    identity adoption (explicitly deferred to U2), Search/Filters/
    History (V), arbitrary uploaded custom icons, a licensed/real
    service-brand-logo catalog, automatic merchant-to-service matching,
    card-number-based network detection, and any broad theme/navigation
    change. `docs/design/*` and `assets/branding/*` were not touched;
    no new asset files were introduced (every new icon uses an existing
    Material Icons glyph already available through the Flutter SDK, and
    every new badge is text-only).

**Files changed:** `lib/core/database/tables.dart` (`Categories
.colorKey`); `lib/core/database/app_database.dart` (schema v13 -> v14,
one `addColumn` + 8 literal backfill `UPDATE`s); `lib/core/database
/repositories/category_repository.dart` (seed `colorKey`, `createCategory`
gains `colorKey`, new `updateCategory`); `lib/features/categories/domain
/category_color.dart` (new); `lib/features/categories/domain
/category_icon.dart` (catalog expanded 8 -> 50, plus `categoryIconKeys`);
`lib/features/categories/domain/category_icon_catalog.dart` (new);
`lib/features/categories/presentation/category_identity_icon.dart` (new);
`lib/features/categories/presentation/category_icon_color_picker.dart`
(new); `lib/features/categories/presentation/categories_screen.dart`
(icon/color pickers on Add, new Edit dialog, list rows now show
`CategoryIdentityIcon` and an edit action); `lib/features/transactions
/presentation/add_transaction_screen.dart`, `lib/features/recurring
/presentation/recurring_screen.dart`, `lib/features/budgets/presentation
/budgets_screen.dart` (category dropdowns/tile now render
`CategoryIdentityIcon`); `lib/shared/widgets/currency_badge.dart` (new);
`lib/shared/widgets/card_network_badge.dart` (new); `lib/features
/accounts/presentation/add_account_form_screen.dart` (currency dropdown
now uses `CurrencyBadge`; a `CardNetworkBadge` selection preview added);
`lib/features/goals/presentation/savings_goals_screen.dart` (target-
currency dropdown now uses `CurrencyBadge`); `lib/features/services
/domain/service_identity.dart`, `lib/features/services/presentation
/service_identity_icon.dart` (new); `lib/l10n/app_en.arb`/`app_ja.arb`
(new icon-label, color-label, and dialog strings; both files' key sets
verified identical). New tests: `test/core/database
/category_color_migration_test.dart`; `test/features/categories/domain
/category_color_test.dart`; `test/features/categories/domain
/category_icon_catalog_test.dart`; expanded `category_icon_test.dart`;
`test/features/categories/presentation/category_identity_icon_test
.dart`; expanded `test/widget/categories_screen_test.dart`; `test/shared
/widgets/currency_badge_test.dart`; `test/shared/widgets
/card_network_badge_test.dart`; `test/features/services/domain
/service_identity_test.dart`; `test/features/services/presentation
/service_identity_icon_test.dart`.

### ADR-044 repair note — Checkpoint U1 validation failure (semantics-tree crash in the category icon/color pickers)

The Windows validation run following ADR-044 reported 7 failing tests
(`+1835 -7`), all of them in `test/widget/categories_screen_test.dart`,
including a detailed report of a repeated `!semantics.parentDataDirty`
framework assertion during `pumpAndSettle()` immediately after opening
the new Edit-category dialog, plus a follow-on `flutter_test` matcher
failure (`min != null && min! > 0`) at the very next assertion in that
same test.

**Root cause (production widget bug, not a test bug):**
`CategoryIconPicker`/`CategoryColorPicker`
(`lib/features/categories/presentation/category_icon_color_picker.dart`)
built each selectable option as `Semantics(button:, selected:, label:)`
wrapping a `Tooltip` wrapping a bare `InkWell` -- with no
`ExcludeSemantics` and no `Material` ancestor for the `InkWell` -- and
`CategoryIconPicker` additionally used a `GridView.builder` (its own
nested `Scrollable`/`Viewport`) inside the dialog's own
`SingleChildScrollView`. This deviates from this codebase's own already-
proven selectable-swatch pattern, `_ThemeSwatchCard` in
`lib/features/settings/presentation/theme_customization_screen.dart`,
which uses a plain `Wrap` (no nested `Scrollable`), no `Tooltip`, and --
the actually load-bearing piece -- explicitly suppresses the descendant
interactive widget's own implicit semantics via
`Semantics(...) > ExcludeSemantics(child: Material(...InkWell...))` so
exactly one `SemanticsNode` exists per option. With ~50 icon options
each contributing several unmerged/conflicting semantics annotations,
built while the dialog's route-transition animation was still running,
the framework's semantics-compilation pass hit a real
`!semantics.parentDataDirty` assertion. The subsequent
`find.byType(TextFormField), findsNothing` matcher failure at the next
line was a cascading symptom of that same corrupted frame, not an
independent bug in the finder/matcher itself -- `findsNothing` was the
correct, valid assertion for "no name field on a system category" and
was left unchanged.

Within `categories_screen_test.dart`, every test that opens the Add or
Edit category dialog renders these same picker widgets and was
therefore a candidate for the identical crash: the 4 new Checkpoint U1
tests that exercise the dialogs, plus the pre-existing
"CP6.7 (D): creating an expense category and an income category both
work end-to-end through the fully localized Japanese Add-category
dialog" test (it opens the Add dialog twice). The 5th new U1 test
("each category row renders exactly one leading icon via
CategoryIdentityIcon") never opens a dialog and does not use these
picker widgets, so it was not implicated.

**Fix (production code only; no test files or generated files
modified):** `category_icon_color_picker.dart` was rewritten so both
pickers follow `_ThemeSwatchCard`'s exact, proven structure --
`CategoryIconPicker` now lays its options out with `Wrap` instead of
`GridView.builder`/`SizedBox(height: 220)`, and every option in both
pickers is `Semantics(button:, selected:, label:) > ExcludeSemantics
(child: Material(color: transparent, child: InkWell(...)))`, with
`Tooltip` removed entirely from both. This is not an accessibility
reduction: the descendant semantics `ExcludeSemantics` removes were
genuinely redundant with (and, left unmerged, in conflict with) the
explicit `label`/`selected`/`button` annotation already provided at the
top of each option -- a screen reader still announces the identical
label and selected state as before, from one authoritative node. The
"never color alone" requirement is unchanged: each option still carries
an explicit accessible label plus a border/check-mark selected
indicator, never color alone.

**Files changed by this repair:**
`lib/features/categories/presentation/category_icon_color_picker.dart`
only.

## ADR-045 — Checkpoint U2: Service / Merchant Identity Integration extends U1's category identity, does not replace or merge with it

Decision: Checkpoint U1 (ADR-044) built category identity (icon+color)
and a category-adjacent `ServiceIdentityKey` enum that nothing yet
persisted. Checkpoint U2's own mandatory pre-implementation audit
confirmed that gap directly -- no transaction or recurring rule had
anywhere to store a chosen service/merchant, and no screen resolved one
into UI. This entry records the one genuine schema change U2 made, the
category-vs-service architecture built on top of it, and the explicit
scope this checkpoint declined (Dashboard, Search/Filters, OCR, cloud
merchant lookup, and a large merchant database all stay out).

1. **Category identity and service identity are two independent,
   optional relationships -- never interchangeable, never one silently
   replacing the other.** A transaction or recurring rule may have
   neither, either, or both. Category answers "what kind of spending is
   this" (`categoryId`, U1's domain) and is unaffected by this
   checkpoint. Service identity answers "who/what is this payment
   associated with" (`serviceIdentityKey`, new) and is presentation
   metadata only, exactly like `categories.icon`/`colorKey` -- never
   read by `FinanceEngine` or any balance/budget/goal calculation.
   Choosing a service never clears, requires, or overrides the category
   choice, and vice versa; both dropdowns render side by side wherever
   this checkpoint integrates them.

2. **The one genuine schema change: `serviceIdentityKey` on
   `transactions` and `recurring_rules`.** Schema version 14 -> 15 adds
   one nullable `TextColumn` to each table -- see
   `app_database.dart`'s `if (from < 15)` migration-step doc comment and
   `tables.dart`'s own doc comments on the two new columns. `categories`
   was already fully covered by U1 and needed no change.
   `recurring_occurrences` was deliberately left untouched: an
   occurrence is a scheduled/handled instance of its rule and always
   inherits the rule's service identity at presentation time rather than
   duplicating it onto every generated occurrence row --
   `RecurringPendingItem`'s presentation already resolves through
   `widget.item.rule`, so no new join or duplicated column was needed
   there. A transfer's `serviceIdentityKey` is defensively forced to
   `null` everywhere a value could otherwise be written
   (`TransactionRepository.updateTransfer`,
   `RecurringRuleRepository.createRule`/`updateRule`'s
   `kind == transfer` branch), mirroring the pre-existing
   `categoryId: null // transfers are never categorized` convention
   exactly -- a transfer is never service-identified for the same reason
   it is never categorized.

3. **A migration hazard specific to `recurring_rules`, resolved by
   reasoning about table creation order, not by running the
   migration.** `recurring_rules` is itself created mid-chain, at
   `if (from < 4)`, via `m.createTable(recurringRules)` -- and Drift's
   generated table object for that `createTable` call already includes
   `serviceIdentityKey` once `tables.dart` declares it, regardless of
   which schema version the fixture claims to start from. Unconditionally
   also calling `m.addColumn(recurringRules, recurringRules
   .serviceIdentityKey)` for every `from < 15` would therefore throw
   "duplicate column" for any upgrade path that passes through
   `from < 4` (creating the table already-complete) before reaching the
   new step. The v15 step guards this addColumn with `if (from >= 4)`,
   exactly mirroring the pre-existing `notifications_enabled`
   `if (from < 4) {...} else if (from == 4) { addColumn(...) }` split
   already in this file. No toolchain was available in this environment
   to execute the migration and observe this firsthand; this was
   determined by inspecting the generated-table/`createTable` semantics
   directly against the existing precedent.

4. **Historical migration-fixture audit, per the brief's explicit
   "remember U1" warning.** Two of the pre-existing minimal fixtures
   (`category_color_migration_test.dart`'s v13 fixture,
   `cloud_account_links_migration_test.dart`'s v7 fixture) were missing
   `transactions`/`recurring_rules` tables that the new v15 step now
   touches, which would have broken them the same way U1's own repair
   note (above) describes for a different pair of tables. Both were
   fixed proactively -- before any test was run, since none could be
   run in this environment -- by adding the missing historically-
   accurate table shapes plus a regression assertion that the newly-
   touched table stays empty after migrating from that fixture. The
   other two historical fixtures that plausibly needed the same review
   (`recurring_migration_test.dart` at v3,
   `savings_goals_migration_test.dart` at v2) were confirmed correct
   as-is: both predate schema v4, where `recurring_rules` is first
   created, so `createTable` -- not `addColumn` -- is what will run for
   them, and `createTable` always uses the current, complete generated
   table definition.

5. **Stable string identifiers, two layers, never a volatile one.**
   `ServiceIdentityFamily` (an 8-value enum -- streaming, music,
   cloudStorage, cloudInfrastructure, ai, productivity, gaming, other --
   each with a `storageValue` string) is the coarse visual family;
   `ServiceIdentityDefinition` (`service_identity_catalog.dart`) is the
   named layer on top of it -- 28 named services plus exactly one
   generic entry per family (36 total), each with a stable `id` that is
   what actually gets persisted into `serviceIdentityKey`. Persisting
   `ServiceIdentityDefinition.id` rather than the family directly is
   what lets a future checkpoint add more named services under an
   existing family without ever touching already-stored data.
   `ServiceIdentityFamily` itself is U1's own `ServiceIdentityKey`,
   renamed and extended (see `service_identity.dart`'s own doc comment
   for why the rename is safe: nothing had ever persisted one of its
   values). `serviceIdentityDefinitionFor(String? key)` never throws:
   `null` resolves to `null` ("no service", distinguishable from
   "unknown service"), and any unrecognized non-null key resolves to the
   catalog's single generic `other` entry -- an old app version's
   choice, or a future catalog revision's removed id, both degrade
   safely rather than crashing the transaction/recurring-rule screens
   that render it.

6. **No brand assets exist in this repo, so none were invented.**
   Exactly as ADR-044 already established for category icons, every
   service identity -- named (Netflix, ChatGPT, AWS, ...) or generic --
   renders through its family's fixed, unbranded Material icon +
   `CategoryColorKey` color pairing (`serviceFamilyIconFor`/
   `serviceFamilyColorFor`), never a company logo. `serviceIdentityCatalog`
   only ever stores an `id`/`family`/`properName` (a plain string, e.g.
   `'Netflix'`) -- never an asset path like `assets/logos/netflix.png` --
   specifically so that a future checkpoint with a genuine licensed
   brand-asset source can extend the family-icon resolver to prefer a
   real logo per named id without any migration, without touching a
   single persisted `serviceIdentityKey` value, and without this
   checkpoint scraping, fabricating, or fetching any logo now.

7. **Visual integration hierarchy: service identity, then category
   identity, then the pre-existing generic fallback -- one shared rule,
   applied consistently, never reinvented per screen.** `Transaction
   IconBadge` gained a `serviceIdentityKey` parameter with the highest
   glyph precedence (service icon > category icon > plain type glyph);
   the tinted container's `color` itself is deliberately left exactly as
   before -- still the caller's transaction-type color
   (error/positive/onSurfaceVariant) -- so "color = financial type"
   stays authoritative in list rows, and full-color service/category
   identity stays reserved for picker/dialog contexts
   (`ServiceIdentityIcon`/`CategoryIdentityIcon`). The same
   service-then-category precedence governs: Activity's row title
   (falls back to category name, then the type word, with the demoted
   name moving into the subtitle rather than disappearing when a service
   takes the title slot), the transaction detail header and its new
   "Service" metadata row (added beside the pre-existing "Category"
   row), the recurring rule dialog's new `ServiceIdentityDropdown`
   (beside its pre-existing category dropdown, both hidden for a
   transfer), and the Recurring/Subscriptions pending-item tile's
   leading icon+color (which, unlike the transaction row, was never
   type-tinted to begin with, so giving a resolved service or category
   its own full color there introduces no conflict).

8. **One shared, stateless picker widget, not a per-screen
   duplicate.** `ServiceIdentityDropdown`
   (`service_identity_picker.dart`) is used unchanged by both the
   Add/Edit Transaction screen and the recurring rule dialog.
   Unlike `_CategoryDropdown` (deliberately duplicated per screen
   because each copy watches a different `categoriesForTypeProvider`
   parameter), `serviceIdentityCatalog` is a plain constant list with
   nothing to watch, so one shared widget is strictly simpler than
   screen-local copies. An unrecognized/legacy persisted value is
   preserved as one synthetic extra dropdown item rather than silently
   discarded, via the same `_itemsPreservingCurrentValue` technique
   `international_preferences_screen.dart` already established.

9. **Accessibility: the proven `DropdownButtonFormField` path, not the
   pattern U1 had to repair.** `ServiceIdentityDropdown` is a standard
   `DropdownButtonFormField`, the same mechanism the pre-existing
   category dropdowns already use safely -- not the custom selectable-
   `Semantics`-grid pattern (`Semantics` + `Tooltip` + `GridView`,
   missing `ExcludeSemantics`) that caused the real semantics-tree crash
   the ADR-044 repair note above documents. Each dropdown item's own
   icon + text is sufficient for Flutter's built-in dropdown-item
   semantics; no nested selectable-`Semantics` widgets are introduced by
   this checkpoint.

10. **CurrencyBadge audit (Phase 8): adopted only where it adds real
    value, not mechanically everywhere.** The two bare
    `Text(currency.code)` currency-picker items in `budgets_screen.dart`
    (`_OverallBudgetDialog`, `_CategoryBudgetDialog`) now render through
    the existing `CurrencyBadge(currencyCode:, showRegionIndicator: true)`
    widget ADR-044 already built, matching the precedent
    `add_account_form_screen.dart` already set for the identical
    "bare currency code inside a picker item" situation. This reuses
    `CurrencyBadge`'s own existing currency-never-implies-country
    safeguard (its small, explicit region-glyph map, which already
    treats EUR/other shared or regionless currencies as having no
    single-country glyph) rather than creating any second
    currency/region registry. `international_preferences_screen.dart`'s
    own richer, pre-existing `_dropdownItem`/`_DropdownField` currency
    rendering (also used by `currency_converter_screen.dart`, and by
    country/language pickers) was deliberately left untouched -- it
    already shows richer currency context than a bare code and is
    outside this checkpoint's "app-wide bare-code dropdown" audit scope.

11. **Card-network audit (Phase 9): no new code needed.** No
    presentation surface beyond account creation/edit (already fully
    covered by ADR-044's `CardNetworkBadge`/`CardNetwork` work) shows a
    saved payment instrument's network. This checkpoint's scope --
    service/merchant identity on transactions and recurring rules --
    never touches payment-instrument display, so nothing here invents an
    unofficial card-network logo or exposes sensitive card detail.

12. **Localization: 10 new ARB keys, English and Japanese, service
    proper names left untranslated.** `serviceOptionalLabel`,
    `serviceFieldLabel`, and 8 `serviceFamily*GenericLabel` keys were
    added to `app_en.arb`/`app_ja.arb` (and hand-synchronized into the
    three generated `app_localizations*.dart` files, since no `flutter
    gen-l10n` toolchain was available in this environment -- see the
    "Remaining issues" section of this checkpoint's report for the exact
    command the maintainer should run to confirm the generated files
    match). `serviceIdentityDisplayName` renders a NAMED service's
    `properName` (e.g. `'Netflix'`, `'ChatGPT'`) verbatim in every locale
    -- brand proper names are not translated -- while every surrounding
    label (the field label, the "None" option, each generic family's own
    label) is fully localized.

13. **Explicitly deferred, per the brief's own scope boundaries.** This
    checkpoint does not touch Dashboard V1, Search/Filters/History, OCR,
    cloud merchant lookup, network logo fetching/scraping, fuzzy/AI
    merchant classification from arbitrary text, navigation, or private
    Net Worth exposure. The service catalog stays at 36 curated entries
    (28 named, 8 generic) -- not a large merchant database -- and
    service selection remains entirely explicit user choice; no
    deterministic auto-detection rule was added in U2, and none is
    planned without a separately-approved, well-tested rule.

**Files changed:** `lib/core/database/tables.dart`; `lib/core/database
/app_database.dart`; `lib/core/database/repositories
/transaction_repository.dart`; `lib/core/database/repositories
/recurring_rule_repository.dart`; `lib/features/services/domain
/service_identity.dart` (evolved from U1); `lib/features/services/domain
/service_identity_catalog.dart` (new); `lib/features/services
/presentation/service_identity_icon.dart` (evolved from U1);
`lib/features/services/presentation/service_identity_picker.dart` (new);
`lib/features/transactions/presentation/transaction_icon_badge.dart`;
`lib/features/transactions/presentation/add_transaction_screen.dart`;
`lib/features/transactions/presentation/activity_screen.dart`;
`lib/features/transactions/presentation/transaction_detail_screen.dart`;
`lib/features/recurring/presentation/recurring_screen.dart`;
`lib/features/budgets/presentation/budgets_screen.dart`; `lib/l10n
/app_en.arb`, `lib/l10n/app_ja.arb`, and the three generated
`app_localizations*.dart` files; `test/core/database
/category_color_migration_test.dart` and `test/core/database
/cloud_account_links_migration_test.dart` (fixture repairs, item 4
above); `test/core/database/service_identity_migration_test.dart` (new);
`test/features/services/domain/service_identity_test.dart` (updated for
the `ServiceIdentityFamily` rename); `test/features/services/domain
/service_identity_catalog_test.dart` (new); `test/features/services
/presentation/service_identity_icon_test.dart` (updated for the
`serviceIdentityKey`-based API).
