# 21. Cloud Account + Sync Architecture (CP12.1 Audit)

Status: Architecture audit and V1 contract definition ONLY. Checkpoint
12.1. **No cloud sync, auth, networking, or backend is implemented by
this document or by CP12.1.** Every table below reflects the schema and
repository code as of HEAD `2171f82` ("Complete V1 recurring and
subscriptions"). No Drift migration was performed to produce this
document -- see §11 for the migrations this audit determines will
eventually be required, none of which have been applied.

This document is authoritative for the sync/cloud-identity topics it
covers. It does not override `00_MASTER_BLUEPRINT.md`, `03_DATABASE_SCHEMA.md`,
or `20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` on any point those
documents already decide -- see "V2 precedence" in `DOCUMENTATION_INDEX.md`.
In particular, household/family/shared-wallet identity is `20_...`'s
V2 §6, and this document deliberately does not re-decide it (see §3).

The governing constraint for every section below: **the app is, and must
remain, local-first.** Every core capability -- capturing a transaction,
computing a balance, evaluating a budget, tracking a savings goal,
scheduling and posting a recurring occurrence, browsing transaction
history -- must continue to work correctly while offline, while signed
out, while the cloud service is unavailable, and while a prior sync
attempt is failing or retrying. Cloud sync is an enhancement layered on
top of a database that already has a single, sufficient source of truth
on-device; it must never become a dependency of ordinary local operation.

---

## 1. Current local data model inventory

Schema version: 7 (`AppDatabase.schemaVersion`). Twelve tables, defined in
`lib/core/database/tables.dart`, all migrations recorded in
`AppDatabase.migration` (`lib/core/database/app_database.dart`) -- there is
no separate `migrations/` directory; every version-to-version step lives
in that one `onUpgrade` callback, guarded by `from < N` checks.

Legend used below: **PK** = primary key; **Owner** = the column that scopes
a row to one local profile (there is currently only ever one profile per
install -- see §3); **Created/Updated/Deleted** = whether that timestamp
column exists at all (not merely whether it's populated); **sync fields**
= whether `sync_version`/`sync_status` columns exist; **offline-ID-safe** =
whether the row's identity is generated locally in a way that can survive
being uploaded to a server and downloaded onto a second device without
remapping (see §4 for what "safe" requires in detail).

### 1.1 `currencies`

| Field | Value |
|---|---|
| PK | `code` (ISO 4217, e.g. `"JPY"`) -- natural key, not a surrogate id |
| Owner | none -- global seed data, not user data |
| Created/Updated/Deleted | none of the three exist |
| sync fields | none exist |
| FKs pointing here | `profiles.home_currency`, `profiles.living_currency`, `accounts.currency_code`, `transactions.currency_code`, `budgets.currency_code`, `savings_goals.currency_code`, `savings_goal_contributions.currency_code`, `recurring_rules.currency_code` (all `references(Currencies, #code)`) |
| Write path | `AppDatabase._seedCurrencies()` only, `insertOrIgnore` from `CurrencyRegistry.seed` (a fixed Dart constant list) -- called once, on `onCreate`. `CurrencyRepository` is read-only. |
| Hard delete | none exists |
| Soft delete | none exists (`is_active` is a fixed seed flag, never toggled by any repository) |
| Transaction boundaries | single `batch()` insert at db-create time |
| Offline-ID-safe | N/A -- this table is never user-authored and must never be pushed to or pulled from a server at all (see §10) |

### 1.2 `profiles`

| Field | Value |
|---|---|
| PK | `id` (client `Uuid().v4()`) |
| Owner | itself -- `ProfileRepository`'s own doc comment: *"Beta 0 has exactly one local profile (no auth, no multi-profile switching yet)"*. No `profileId` parameter exists on any read/create method because there is, by construction, at most one row. |
| Created/Updated/Deleted | `created_at`/`updated_at` exist; **no `deleted_at`** |
| sync fields | **none exist** -- no `sync_version`/`sync_status` columns at all |
| Write paths | `createProfile` (throws `StateError` if a row already exists), `updateHomeAndLivingCurrency`, `updateInternationalPreferences`, `updateThemePreference` -- four narrow, single-row writers, no generic "update profile" method |
| Hard delete | none exists |
| Soft delete | none exists -- there is no delete path for a profile at all today |
| Transaction boundaries | each write is one `UPDATE ... WHERE id = ?` or one `INSERT`; no multi-table transaction |
| Offline-ID-safe | id itself: yes (client UUID). **But this table's whole shape is wrong for a cloud identity** -- see §3, this is the single most important finding of this audit for the identity contract. |

### 1.3 `categories`

| Field | Value |
|---|---|
| PK | `id` (fixed string for the 8 seeded system rows, e.g. `"sys-groceries"`; client `Uuid().v4()` for a user-created one) |
| Owner | `profile_id`, **nullable** -- `null` means a shared system category (seeded once, shared by every profile/install, never profile-scoped) |
| Created/Updated/Deleted | **none of the three exist.** No `created_at`, no `updated_at`, no `deleted_at`. |
| sync fields | **none exist** |
| Write paths | `seedSystemCategoriesIfNeeded()` (`insertOrIgnore`, fixed ids, idempotent), `createCategory` (client UUID insert). **No update method and no delete method exist anywhere in the app today** -- a category, once created, is permanently immutable and permanently present from the repository's point of view (only `is_active`/`sort_order`/`parent_id` columns exist for a future UI that doesn't write to them yet). |
| Hard delete | none exists |
| Soft delete | none exists (no write path sets `is_active` to `false` or exists to do so) |
| Transaction boundaries | single-row inserts; the seed is one `batch()` |
| Offline-ID-safe | user-created rows: yes (client UUID). System rows: **no** -- they use fixed string ids that are not globally unique across a from-scratch seed on a second device unless the seed list itself is guaranteed identical and stable, which it currently is (a hardcoded Dart constant), but that is an implicit assumption a future edit to the seed list could break silently. |
| **Gap flagged for §11** | This table has none of `created_at`/`updated_at`/`deleted_at`/`sync_version`/`sync_status` -- of every table in the schema, this is the one most obviously not sync-ready as-is. |

### 1.4 `accounts`

| Field | Value |
|---|---|
| PK | `id` (client `Uuid().v4()`) |
| Owner | `profile_id` (FK -> `profiles.id`) |
| Created/Updated/Deleted | `created_at`/`updated_at`/`deleted_at` all exist |
| sync fields | **none exist** -- unlike every table added from schema v2 onward, `accounts` (a v1/Beta-0 table) was never given `sync_version`/`sync_status` |
| Write paths | `createAccount` (client UUID insert), `softDelete` (sets `deleted_at` + `is_active = false`). **No update/rename method exists** -- an account's name/type/currency cannot be edited today. |
| Hard delete | none exists |
| Soft delete | yes, via `softDelete(id)` |
| Transaction boundaries | single-row writes only |
| Offline-ID-safe | yes -- client UUID, never reused, never remapped by anything that reads it back |
| **Gap flagged for §11** | Missing `sync_version`/`sync_status` -- needs the same additive columns `transactions`/`budgets`/etc. already carry. |

### 1.5 `transactions` -- **the core financial ledger**

| Field | Value |
|---|---|
| PK | `id` (client `Uuid().v4()`, generated in `TransactionRepository._insert`) |
| Owner | `profile_id` |
| Created/Updated/Deleted | all three exist |
| sync fields | `sync_version` (`int`, default `0`), `sync_status` (`text`, default `'localOnly'`) -- both exist, but see the note below |
| FKs | `account_id` (source, or the only account for expense/income), `destination_account_id` (nullable, transfer only), `category_id` (nullable, never set for a transfer), `profile_id`, `currency_code` |
| Write paths | `recordExpense`/`recordIncome`/`recordTransfer` (all funnel into one private `_insert`), `updateExpense`/`updateIncome`/`updateTransfer` (type-immutable -- editing can never turn an expense into an income/transfer; re-validates currency match on every edit), `softDelete` |
| Hard delete | none exists |
| Soft delete | yes, via `softDelete(id)` |
| Transaction boundaries | `_insert` is one `INSERT`; `_updateExpenseOrIncome`/`updateTransfer` use a `WHERE id = ? AND deleted_at IS NULL AND type = ?` guard and check `rowsAffected == 1`, throwing `TransactionNotFoundException` otherwise -- a race-safety check against the row having been deleted (or, unreachably today, retyped) between an earlier read and this write, but this is a single-statement write, not a multi-statement local transaction |
| Offline-ID-safe | yes -- client UUID |
| **Important existing note (already inert, not yet load-bearing)** | `sync_version`/`sync_status` exist on this table **but no write path ever sets them to anything other than their column defaults.** `TransactionRepository._insert`'s own comment says so explicitly: *"syncVersion / syncStatus deliberately left at their column defaults (0 / 'localOnly' -- ADR-020); Beta 0 never sets them explicitly."* They are placeholders, not yet meaningful data -- see §1.11 below and §4. |

### 1.6 `budgets`

| Field | Value |
|---|---|
| PK | `id` (client UUID) |
| Owner | `profile_id` |
| Created/Updated/Deleted | all three exist |
| sync fields | `sync_version`/`sync_status` exist (same inert-placeholder caveat as `transactions`) |
| Write paths | `setOverallBudget`/`setCategoryBudget` -> one private `_upsert`: **SELECT the existing active row for the (profile, category, currency, year, month) key, then either UPDATE it or INSERT a new row** -- an application-layer "at most one active row per key" invariant, enforced entirely in Dart, with **no DB uniqueness constraint** and **no wrapping `_db.transaction()`** around the read-then-write. `softDelete`. |
| Hard delete | none exists |
| Soft delete | yes |
| Transaction boundaries | **none** -- the upsert's read and write are two separate statements with no transactional wrapper. Locally this is safe because Beta 0/1 is single-writer, single-process. It stops being safe the moment two writers (two devices, or a client and a sync-apply pass) can race on the same key -- flagged again in §2 and §5. |
| Offline-ID-safe | yes |

### 1.7 `savings_goals`

| Field | Value |
|---|---|
| PK | `id` (client UUID) |
| Owner | `profile_id` |
| Created/Updated/Deleted | all three exist |
| sync fields | exist (inert placeholder, as above) |
| Write paths | `createGoal`, `updateGoal` (currency is permanently anchored at creation -- rejects any `targetAmount` in a different currency, never coerces), `softDeleteGoal` |
| Hard delete | none exists |
| Soft delete | yes. **Deliberately does not cascade** -- a soft-deleted goal's `savings_goal_contributions` rows are left physically in place; every read path simply stops treating the parent goal as active. |
| Transaction boundaries | single-row writes |
| Offline-ID-safe | yes |

### 1.8 `savings_goal_contributions` -- append-only ledger

| Field | Value |
|---|---|
| PK | `id` (client UUID) |
| Owner | via `goal_id` -> `savings_goals.profile_id` (no direct `profile_id` column on this table itself) |
| Created/Updated/Deleted | **`created_at` and `deleted_at` exist; there is no `updated_at`** -- by design: a contribution can be deleted but never edited (`SavingsGoalContributionRepository` has no update method at all) |
| sync fields | exist (inert placeholder) |
| Write paths | `addContribution` (validates: amount positive, parent goal exists and is active via `requireActiveGoal`, currency matches the parent goal's currency exactly -- `currency_code` is duplicated from the parent at write time, not read via a join), `softDeleteContribution` |
| Hard delete | none exists |
| Soft delete | yes |
| Transaction boundaries | single-row writes; the parent-goal existence/activity check is a separate prior read, not wrapped with the insert in one `_db.transaction()` |
| Offline-ID-safe | yes |

### 1.9 `recurring_rules` -- schedule/template only

| Field | Value |
|---|---|
| PK | `id` (client UUID) |
| Owner | `profile_id` |
| Created/Updated/Deleted | all three exist |
| sync fields | exist (inert placeholder) |
| Write paths | `createRule`/`updateRule` (validates amount, interval >= 1, currency-account match for expense/income, source != destination + shared currency for transfer -- same currency-match rigor `TransactionRepository.recordTransfer` enforces), `softDelete` |
| Hard delete | none exists |
| Soft delete | yes. A soft-deleted rule can never post a new occurrence again (`RecurringOccurrenceRepository.postOccurrence`/`skipOccurrence` both call `requireActiveRule` first), but its already-posted `transactions` rows and already-handled `recurring_occurrences` rows are left untouched. |
| Transaction boundaries | single-row writes |
| Offline-ID-safe | yes |

### 1.10 `recurring_occurrences` -- immutable handled-occurrence facts

| Field | Value |
|---|---|
| PK | `id` (client UUID) |
| Owner | via `rule_id` -> `recurring_rules.profile_id` (no direct `profile_id` column) |
| Created/Updated/Deleted | **only `created_at` and `handled_at` exist. There is no `updated_at` and no `deleted_at` at all.** |
| sync fields | exist (inert placeholder) |
| Write paths | `postOccurrence` / `skipOccurrence`, both wrapped in **`_db.transaction()`** (the one genuinely multi-statement local transaction in this codebase: `postOccurrence` writes a real `transactions` row via `TransactionRepository` AND a `recurring_occurrences` row atomically -- either both commit or neither does). Uniqueness (at most one row per `(rule_id, scheduled_date)` pair) is enforced by checking-then-rejecting with `RecurringOccurrenceAlreadyHandledException` -- checked once before the transaction and **re-checked again inside it**, specifically to defend against a race between the pre-check and the write. |
| Hard delete | none exists |
| Soft delete | **none exists -- there is no delete method for this table at all.** A handled occurrence, once written, is permanent. |
| Transaction boundaries | the only table in the schema with an explicit multi-statement atomic write |
| Offline-ID-safe | yes |
| Note | This table's uniqueness constraint -- one row per `(rule_id, scheduled_date)` -- is exactly the kind of invariant that needs a server-side idempotency guarantee under retry (see §2, §7): retrying `postOccurrence` for the same rule/date must never create a second transaction. |

### 1.11 `transaction_exchange_rates` -- reserved, currently unused in production

| Field | Value |
|---|---|
| PK | `id` (client UUID) |
| Owner | via `transaction_id` -> `transactions.profile_id` |
| Created/Updated/Deleted | `fetched_at`/`provider_timestamp` exist as instants; **no `created_at`, no `updated_at`, no `deleted_at`** |
| sync fields | **none exist** |
| Write paths | `TransactionExchangeRateRepository.attach` only -- throws `FxSnapshotAlreadyExistsException` if the transaction already has a snapshot (immutable-once-written, application-layer enforced, not a DB constraint) |
| Hard delete | none exists |
| Soft delete | none exists |
| Transaction boundaries | single-row insert; the class's own doc admits the check-then-insert is *"not concurrency-safe against two simultaneous writers -- acceptable under the...local-only, single-writer-at-a-time scope"* |
| Offline-ID-safe | yes, but moot for now |
| **Status** | This table has existed since schema v1 specifically so a future checkpoint would never need a migration to add it (ADR-009/ADR-010/ADR-020), but **nothing in production calls `attach` yet** -- no transaction-creation or edit flow wires it up. It is dormant. Flagged in §11 as needing sync-shape columns (`created_at`/`updated_at`/`deleted_at`/`sync_version`/`sync_status`) only once/if it is actually wired into a live feature -- there is no urgency while it holds zero rows in every real install. |

### 1.12 `reference_exchange_rates` -- device-local cache, by design

| Field | Value |
|---|---|
| PK | composite `(base_currency, quote_currency)` -- **the one deliberate departure from this schema's surrogate-`id` convention**, documented in the table's own doc comment: this row has no independent identity, nothing else references it by id, and it needs SQLite-enforced "at most one row per pair" plus upsert-on-conflict semantics, not the reject-a-second-write semantics `transaction_exchange_rates` needs for a completely different (immutability) reason |
| Owner | none -- not user data at all |
| Created/Updated/Deleted | `observed_at`/`fetched_at` exist as instants; no `created_at`/`updated_at`/`deleted_at` |
| sync fields | none exist |
| Write paths | `DriftReferenceFxRateCache.put` -- `insertOnConflictUpdate`, always succeeds, always replaces in place |
| Hard delete | **yes** -- `removeIfPresent`, the only genuine hard `DELETE` anywhere in the entire repository layer (`_db.delete(_db.referenceExchangeRates)...go()`) |
| Soft delete | none, and none is needed |
| Transaction boundaries | single-statement upsert/delete |
| Offline-ID-safe | N/A |
| **Status** | This is a replaceable market-quote cache with a completely different lifecycle from every other table -- see its own class doc: *"Two independent lifecycles, on purpose."* It must never sync (§10). |

### 1.13 Device-local data that is not a Drift table at all

Two other categories of local state exist outside the database entirely,
and are relevant to §10:

- **`shared_preferences`**: `favoriteCurrencyPairsProvider` (Currency
  Converter favorites) is explicitly documented as *session-only, in-memory*
  today (ADR-028) -- it does not even use `shared_preferences` yet, despite
  that package now being a dependency (added for `activity_filter_provider.dart`'s
  screen-local search/filter state, itself an `autoDispose` Riverpod
  provider that is never persisted at all, by construction).
- **OS-level scheduled notifications** (`flutter_local_notifications`):
  `NotificationIdAllocator` deterministically derives a notification id from
  `(rule_id, scheduled_date_utc)` via a stable hash -- nothing about a
  scheduled reminder is ever written to Drift; it is recomputed and
  reconciled fresh from `recurring_rules`/`recurring_occurrences` every time
  the app decides what should be scheduled.

### 1.14 Summary: are `deleted_at`/`sync_version`/`sync_status`'s current semantics sufficient for V1 sync?

**`deleted_at`:** semantics are sufficient and consistent everywhere it
exists. Every table that has it stores a genuine UTC instant, set exactly
once (no table un-deletes a row), and every read path already excludes
`deleted_at IS NOT NULL` rows as a matter of course. The one gap is
`categories` and (partially) `recurring_occurrences`/`savings_goal_contributions`
(intentionally immutable-once-written, so a delete concept was never
built for the latter two) not having it at all -- see §11.

**`sync_version`/`sync_status`:** **not sufficient as currently defined,
because nothing currently defines their semantics beyond a column
default.** Every write path leaves them at `0`/`'localOnly'`; no code
anywhere increments `sync_version`, transitions `sync_status`, or reads
either column back for a decision. They were added purely as
forward-compatible placeholders (ADR-020's own stated purpose). Before
CP12.3, these need an actual state machine: at minimum, `sync_status`
needs to distinguish "never touched by sync" / "pending push" / "pushed,
awaiting acknowledgement" / "synced" / "in conflict", and `sync_version`
needs to become a genuinely monotonic per-record counter that increments
on every local mutation. Reusing the existing column names/types for that
real semantics is very likely fine (an `UPDATE` that also increments an
existing `int` column and rewrites an existing `text` column touches no
schema, no migration) -- see §11's explicit "no schema change needed"
conclusion for this specific pair of columns.

---

## 2. Money / accounting invariants sync must not violate

These already hold today, verified directly in code, and every one of
them is a hard constraint on any sync design, not merely a preference:

1. **Signed 64-bit integer minor units, never floating point.** `Money`
   (`lib/core/money/money.dart`) wraps a Dart `int` (platform-native
   signed 64-bit) and is architecturally incapable of wrapping a `double`
   -- there is no constructor path that accepts one. Every `*MinorUnits`
   Drift column is `IntColumn`. A sync payload must carry `amountMinorUnits`
   as a JSON integer, never a JSON number that could round-trip through a
   float, and the server's own numeric type must be an exact integer
   (PostgreSQL `bigint`), never `numeric`/`double precision` reinterpreted
   loosely or a client-side float decode.
2. **Original transaction currency/amount is preserved, forever.**
   `transactions.currency_code` and `amount_minor_units` are never
   rewritten by anything except the transaction's own `updateExpense`/
   `updateIncome`/`updateTransfer` (which re-validate, never silently
   convert) -- a synced record must arrive and be applied with its
   original currency intact, never re-denominated by a client-side FX
   step during apply.
3. **Transfers never become income/expense, and vice versa.**
   `_updateExpenseOrIncome`/`updateTransfer` both throw `ArgumentError` if
   the existing row's `type` doesn't match -- type is immutable after
   creation, full stop. A remote mutation payload must never be allowed to
   change a record's `type`; if a future edit needs to change type, the
   product's existing answer is "delete and recreate," and sync must
   preserve that, not add a new "retype in place" capability.
4. **Same-currency transfer restriction remains V1 behavior.**
   `recordTransfer`/`updateTransfer` both throw `CurrencyMismatchException`
   if the source and destination accounts (or the amount) don't share a
   currency -- enforced at the repository layer independent of the UI
   (ADR-019). A sync-applied transfer mutation must run through the exact
   same validation before being committed locally, never bypass it because
   "the server already accepted it."
5. **Account balances must never double-count.** Balance is **derived**,
   never stored: `FinanceEngine` recomputes `openingBalance + sum(non-deleted
   transactions touching this account)` from scratch every time (confirmed
   directly in `finance_engine.dart`: every fold explicitly skips
   `tx.isDeleted`). There is no `accounts.balance` column to keep in sync
   at all -- sync only ever needs to reconcile `accounts.opening_balance_minor_units`
   and the `transactions` rows themselves; the balance is automatically
   correct as long as (a) no transaction is duplicated and (b) a
   soft-deleted transaction never comes back. Both of those are pure
   consequences of the idempotency and tombstone rules in §5/§6 --
   there is no separate "balance sync" concept to get right or wrong.
6. **Deleted records remain excluded, from every read path, unconditionally.**
   Every `watch*`/`require*` method that matters filters `deleted_at IS
   NULL` (or, for `recurring_rules`, `requireActiveRule`) at the query
   level -- never as an afterthought in the UI. A pulled remote tombstone
   must set the same `deleted_at` column through the same code path (or an
   equivalent one), never a different "hidden" flag that the existing read
   paths don't already know to check.
7. **Historical financial data must not silently change due to current
   FX.** `transaction_exchange_rates` (§1.11) is an immutable-once-attached
   historical fact, architecturally separate from `reference_exchange_rates`
   (§1.12), which is a replaceable *current* quote cache with **no
   connection to any transaction** (its own class doc: *"this table is
   never joined to it, read from it, or written from it"*). Sync must
   preserve that separation exactly: reference-rate cache rows never sync
   (§10) and never retroactively touch a transaction; a synced FX snapshot
   (if/when that feature goes live) is written once and never overwritten.
8. **Recurring occurrence posting must not duplicate transactions.**
   `postOccurrence`'s uniqueness check (one row per `(rule_id,
   scheduled_date)`, checked before AND inside its `_db.transaction()`) is
   exactly the guarantee that must extend across devices: two devices
   posting the same rule's same scheduled date (one offline, one online,
   or a retried push) must resolve to exactly one `transactions` row and
   exactly one `recurring_occurrences` row, never two.
9. **Subscriptions remain a view, not a second accounting model.**
   `subscription_providers.dart` computes everything from
   `recurring_rules`/`recurring_occurrences` that already exist -- there is
   no `subscriptions` table and none should ever be introduced for sync
   either; syncing `recurring_rules` correctly is sufficient.
10. **Goal contributions must not duplicate.** `savings_goal_contributions`
    is append-only by design (no update method exists at all) with each
    row's own client UUID as its identity -- the same idempotent-create
    discipline as `transactions` applies: a retried "add contribution"
    push must be recognized as the same mutation, not a second
    contribution.
11. **Reference FX cache must never become authoritative for a
    transaction's FX.** Restated from point 7 because it is easy to get
    backwards during implementation: even a perfectly-synced
    `reference_exchange_rates` row must never be read by anything that
    also touches `transactions`/`transaction_exchange_rates`.

**Database uniqueness/idempotency constraints this implies for sync
retry/replay**, none of which exist as DB constraints today (every one is
currently an application-layer check only -- ADR-019/021/022/023's shared
precedent):

- `recurring_occurrences`: unique on `(rule_id, scheduled_date)`.
- `budgets`: unique on `(profile_id, category_id, currency_code, year,
  month)` **among active (`deleted_at IS NULL`) rows only** -- a
  soft-deleted row for the same key must not block a new one, exactly as
  today's `_upsert` already relies on.
- `transaction_exchange_rates`: unique on `transaction_id` (once wired up).
- A **client-mutation-id** uniqueness constraint (see §4) is what actually
  has to protect every create-style write (`transactions`, `savings_goal_contributions`,
  `recurring_occurrences`, etc.) against a retried push creating a second
  row -- the natural-key uniqueness above is necessary but not sufficient
  on its own for e.g. a legitimately-intended second transaction that
  happens to look similar; only a client-generated idempotency key
  distinguishes "this is a retry of the same mutation" from "this is a new,
  separate mutation that happens to have the same shape."

---

## 3. V1 identity / account contract

### 3.1 Why the existing `profiles` row must NOT become the auth identity

Three separate facts already established in §1.2 make this the wrong
foundation, not merely a style preference:

- It is explicitly documented and enforced as **exactly one row per
  install, with no concept of "which profile"** anywhere in its own
  repository's API. Turning it into a multi-tenant, server-verified
  identity would require rewriting its entire access pattern, not adding
  a column.
- It has **no `deleted_at`** and **no sync fields at all** -- of every
  table in the schema, it is one of only two (with `categories`) that
  currently has zero sync-readiness.
- It mixes **identity-adjacent fields** (`display_name`) with **pure
  locale/UI preference** (`home_country`, `current_country`,
  `preferred_language`, `timezone`, `date_format`, `number_format`,
  `theme_preference`) in one row with no separation -- a cloud identity
  needs a stable boundary that a preference edit can never touch, and
  today's `profiles` row has no such boundary.

### 3.2 The V1 model: two separate concepts, cleanly split

**LOCAL PROFILE** (today's `profiles` table, unchanged in shape):
purely a local preferences/locale record. It continues to exist,
continues to work exactly as it does today, offline, signed out, forever.
It answers "what does this install look/behave like" -- never "who is
this."

**CLOUD IDENTITY** (does not exist yet; not designed as a schema in this
document beyond the shape below, since CP12.1 does not implement auth):
a separate, server-issued, stable identifier for the person, obtained
only once they choose to sign in. The smallest safe V1 shape:

- **`cloud_user_id`**: a stable, server-assigned identifier (never
  client-generated -- unlike every other id in this schema, this one MUST
  originate from the server/auth provider, because it is the one identity
  concept a client cannot be trusted to self-assign without opening an
  impersonation hole). Never reused, never recycled.
- **A local `profile_id` <-> `cloud_user_id` link**, stored once, locally
  (a new, tiny table or a single nullable column added to `profiles` --
  a real decision for CP12.2, not decided here) that records "this local
  profile is currently signed in as this cloud user." This link is the
  entire ownership mapping V1 needs: every synced record's `owner_user_id`
  (§4) is this `cloud_user_id`, resolved at push time from the current
  session, **never** trusted from client input on the server side (§8).
- **Device/install id**: needed, but only as an opaque, locally-generated
  identifier (a UUID generated once per install and persisted locally,
  not tied to any hardware serial/IMEI/advertising id -- there is no
  privacy or App Store justification for anything more identifying) used
  purely for diagnosing "which device pushed this mutation" and for
  scoping local-only sync-engine state (a pending-mutation queue, a pull
  cursor) that must NOT itself sync (§10) -- it is not part of the
  identity contract's trust boundary, only an operational label.

### 3.3 Session boundary

Authentication and its session are entirely separate from the local
database's read/write path. A user can be signed out and still fully use
every existing feature (§0's local-first mandate) -- signing in only ever
*adds* the ability to push/pull; it never gates local reads/writes. The
session boundary is: an access/session token exists only in memory plus
whatever secure-storage mechanism CP13 (security) designs -- never in the
Drift database, never in a synced table (§9).

### 3.4 Behavior contract, V1

- **Signed-out**: full local functionality; no push, no pull; nothing
  queued for sync is lost -- it simply waits.
- **First sign-in on a device that already has local data**: the
  existing local profile's data becomes eligible to push, associated with
  the newly-obtained `cloud_user_id`. V1 does not need to support merging
  two *different* pre-existing local histories under one cloud identity
  (that is a genuinely hard problem -- explicitly deferred); it only needs
  to support "this one local dataset now has a cloud home."
- **Sign-out**: stops push/pull. Local data is untouched and remains
  fully usable (§0). Any mutation made while signed out is queued exactly
  like an offline mutation and pushes automatically on the next sign-in
  (same code path as "was offline, network came back" -- see §7).
- **Reinstall / new device**: today, reinstalling **loses everything** --
  confirmed directly: `native_connection.dart` opens the SQLite file
  inside the OS application-documents directory, which both Android and
  iOS delete on uninstall, and there is no backup mechanism today. This is
  precisely the gap cloud sync exists to close. V1 behavior: signing in
  on a fresh install with no local data pulls the cloud user's full
  current state down and reconstructs the local database from it.
- **Account deletion**: a distinct, explicit, harder-to-reverse action
  from ordinary record deletion -- see §6.4. Not designed in schema detail
  here; flagged as a CP12.2+ decision that must exist before V1 ships,
  not an afterthought.
- **Multiple devices**: V1 must support a user signed into the *same*
  cloud identity on more than one device, each pushing/pulling
  independently against the same server-side record set -- this is the
  ordinary, expected case sync exists for, not an edge case.
- **Multiple cloud accounts on one device, at once**: **not supported in
  V1.** One signed-in cloud identity at a time, matching today's
  one-local-profile-per-install shape exactly (§3.1) -- no multi-account
  switcher, no simultaneous dual-session. Switching accounts is treated as
  sign-out-then-sign-in (§12 covers the failure-mode implications of a
  signed-out-with-pending-mutations transition, and of switching into a
  *different* account, explicitly).
- **Household / shared wallet identity**: explicitly out of scope for
  V1, deferred to `20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` V2 §6,
  which already reserves this space -- this document does not re-decide
  it and CP12.2-12.7 must not attempt it.

---

## 4. V1 sync record / envelope contract

Every field below is justified against a concrete need already
established above -- nothing is included merely because generic sync
systems tend to have it.

| Field | Owned by | Why it's needed | Why it's distinct from the others |
|---|---|---|---|
| `id` | Client (unchanged -- already exists, already a UUID on every syncable table per §1) | The record's own stable identity, usable identically before and after it ever touches the server. | Distinct from every field below: this identifies *the record*, not a mutation, a schema, or a revision. |
| `owner_user_id` | **Server**, at push-acceptance time, resolved from the caller's authenticated session -- never taken from the request body | Enforces ownership without trusting the client (§8's "server must not trust client-supplied ownership" rule) | Distinct from `id`: many records share one `owner_user_id`; distinct from the local `profile_id`, which never leaves the device (§3) and is not what the server keys on. |
| `entity_type` | Client, fixed per table (e.g. `"transaction"`, `"budget"`) | The push/pull envelope is generic across tables (§7); the server needs to know which table/shape a payload deserializes into. | Distinct from a Drift `Type` -- this is a small closed string enum, not a class name, so it's stable across refactors of the Dart code. |
| `payload` | Client | The actual entity fields (everything §1's per-table columns already define, minus the sync envelope fields themselves). | Kept as one opaque, versionable blob at the envelope level rather than flattened, so entity shape changes (a future migration) don't force an envelope-format change. |
| `sync_version` (per-record) | **Client**, incremented on every local mutation of that record | This is what §1.14 identified as needing real semantics: a monotonic local counter that lets the client say "I am pushing the Nth version of this record I know about." | **Must not be confused with the Drift `schemaVersion` integer** (`AppDatabase.schemaVersion`, currently `7`) -- that number describes the shape of the *whole local database*; this one describes one *record's* mutation count. Conflating them would mean every local sync bump looks like a schema migration and vice versa. |
| `server_revision` | **Server**, assigned/incremented on accept | The server's own authoritative ordering/version for the record, returned in every push acknowledgement and every pull response -- what the client's next push must present as "the revision I last saw" for conflict detection (§5). | Distinct from `sync_version`: `sync_version` is the client's own count of ITS edits; `server_revision` is the server's count of what it has actually accepted, across every device. A client that has never talked to the server has a `sync_version` but no `server_revision` yet. |
| `client_mutation_id` | Client, one fresh UUID **per mutation attempt's logical intent**, reused verbatim across retries of that same attempt | The idempotency key: the server accepts a push exactly once per `client_mutation_id`, so a network-timeout retry of an already-accepted push is recognized and returns the original acknowledgement rather than applying (or rejecting) the mutation a second time. | Distinct from `id`: the same record `id` can be mutated by many different `client_mutation_id`s over its life (one per edit); distinct from `sync_version`: a retried push of "the same" mutation reuses one `client_mutation_id` but is still exactly one bump of `sync_version`, not two. |
| `created_at` / `updated_at` | Client (already exist per-table, §1) | Already-established, already-correct UTC-instant columns; the envelope just carries them through unchanged. | Distinct from every revision/version field above -- these are calendar-meaning fields the UI displays, never used for conflict resolution ordering (that's `server_revision`'s job -- clock skew across devices makes wall-clock timestamps an unsafe tie-breaker on their own, see §5). |
| `deleted_at` / tombstone flag | Client (existing column) or an explicit tombstone marker on the envelope | Carries a soft-delete through the same path as every other mutation -- see §6. | Distinct from a hard delete: nothing in this contract ever removes a row from the server or the client; §6 covers exactly why. |

**Which side owns which timestamp/revision, restated plainly:** the
client owns `created_at`, `updated_at`, and `sync_version` (its own local
mutation count); the server owns `server_revision` and `owner_user_id`.
`client_mutation_id` is minted by the client but its *acceptance* --
exactly-once semantics -- is enforced by the server. Nothing here is
conflated: local DB schema version, per-record sync version, server
revision, and client mutation/idempotency id are four different numbers
answering four different questions, and no code path should ever compare
two of them to each other.

---

## 5. Conflict policy, per entity class

V1's governing rule: **prefer preserving data over silently discarding
either side.** Where automatic last-writer-wins is genuinely safe (a pure
preference with no financial consequence), say so explicitly; everywhere
else, prefer a policy that is simple enough to test exhaustively over one
that is merely clever.

- **Profile/preferences** (local-only per §3 -- not actually synced as a
  record at all in V1, since the cloud identity link is a separate
  concept from the `profiles` row's UI-preference fields): if a future
  version syncs preference fields, last-write-wins by `server_revision`
  is safe -- there is no financial consequence to a language or theme
  setting losing a race.
- **Accounts**: last-write-wins on non-financial fields (name, type) is
  acceptable once an update method exists (§1.4 notes none does yet).
  `opening_balance_minor_units` is more sensitive -- prefer rejecting a
  push whose `server_revision` doesn't match what the client last saw
  (a real conflict) over silently overwriting a balance figure, and
  surface it to the user rather than resolving it silently.
- **Categories**: last-write-wins is safe for name/icon edits (low
  financial stakes, and today there is no edit path at all -- §1.3);
  a delete-vs-edit conflict (§ below) still applies once a delete path
  exists.
- **Transactions**: **never silently merge or drop.** A concurrent edit
  to the *same* transaction id from two devices is a genuine conflict --
  V1 keeps whichever side the server accepted first (by `server_revision`)
  as canonical, and the losing device's local copy is replaced with the
  canonical version on its next pull, but the losing edit is preserved in
  a way the user can be shown ("this transaction was changed on another
  device") rather than vanishing with no trace, until CP12.2+ decides the
  exact UI. **Never auto-merge two different edits' field values into a
  new fabricated transaction** -- financial records lose meaning as soon
  as two people's independent edits are blended.
- **Budgets**: the existing app-layer uniqueness (§2, one active row per
  key) means the real conflict case is two devices independently creating
  a budget for the *same* key while both offline -- resolved the same way
  as a duplicate-create generally (§ below): the server keeps the first
  `client_mutation_id` it accepts for that key; the second create for the
  same key, arriving later, is treated as an edit of the now-existing row
  rather than a rejected duplicate, mirroring `_upsert`'s own existing
  local semantics (§1.6) rather than inventing new behavior sync-side.
- **Savings goals**: currency is permanently anchored (§1.7) -- a
  conflicting edit can never change currency regardless of ordering (the
  server-side validation must enforce this exactly as the local repository
  already does, §8). Name/target-amount/target-date edits: last accepted
  `server_revision` wins, loser is shown, same as transactions.
- **Goal contributions**: append-only, no edit path exists (§1.8) --
  there is no "concurrent edit" case to resolve, only duplicate-create
  (below) and delete-vs-nothing (a contribution can be soft-deleted on one
  device while untouched on another; the tombstone simply propagates, §6).
- **Recurring rules**: same treatment as accounts/goals for field edits
  (last-accepted-revision wins, loser shown). A **delete-vs-edit** case
  matters more here than most tables, because deleting a rule changes
  future behavior (no more occurrences can post against it) -- if one
  device deletes a rule while another edits it, the delete wins
  (soft-deleted state is terminal for this table already, §1.9) and the
  edit is discarded with the same "shown to the user" treatment, never
  silently resurrecting the rule to apply the edit.
- **Recurring occurrences**: **immutable once written, no edit path
  exists at all** (§1.10) -- the only conflict that can occur is a
  duplicate-create (two devices posting/skipping the same
  `(rule_id, scheduled_date)` independently while both offline), which is
  exactly what the idempotency + natural-key-uniqueness combination in §2
  exists to prevent: the server accepts the first `client_mutation_id`
  it sees for that `(rule_id, scheduled_date)` pair and rejects the
  second with a definite, structured "already handled" response (mirroring
  `RecurringOccurrenceAlreadyHandledException`'s existing local shape) --
  never two occurrence rows, never two transactions.

**General cases, resolved once rather than per-entity:**

- **Retry of the same mutation**: absorbed entirely by `client_mutation_id`
  (§4) -- the server returns the original result, no new effect.
- **Duplicate create** (two independent creates that happen to collide on
  a natural key, e.g. two budgets for the same month): resolved per-entity
  above; the general rule is "first accepted `client_mutation_id` for that
  key wins, later ones become edits or are surfaced as conflicts,
  never silently duplicated."
- **Offline edit followed by a remote edit** (same record, different
  devices, no true overlap in wall-clock time -- e.g. device A edits while
  fully offline for a day, then device B edits and pushes successfully
  before A ever reconnects): when A finally pushes, its `sync_version`/
  last-known `server_revision` will be stale relative to what the server
  now holds -- this is a conflict by the same rule as "concurrent edit,"
  not a special case; A's push is rejected with the current server state
  attached, and CP12.2+'s UI decides how to present it to the user, but
  it is never silently overwritten in either direction by the sync engine
  itself.
- **Server acknowledgement arriving after a newer local edit**: if the
  user edits a record again locally before the earlier push's ACK comes
  back, the local `sync_version` has already moved past what that ACK
  refers to -- the ACK for the older push is recorded (so its
  `client_mutation_id` is not retried), but it must not overwrite the
  newer local edit that's already queued to push next.

**Where automatic merge is safe vs. not, restated plainly**: safe only
for fields with no financial meaning and no cross-table consequence
(name/label/icon/preference-shaped fields). Never safe for anything that
determines an amount, a currency, a type, a date that recurrence math
depends on, or an active/deleted state -- those always resolve to "keep
the server-accepted version, surface the conflict," never a blended
value.

---

## 6. Deletion / tombstone contract

**Current behavior, audited (§1 has the per-table detail):** every
syncable financial table already soft-deletes via a `deleted_at` instant
column except `categories` (§1.3, no delete path exists at all) and
`recurring_occurrences` (§1.10, immutable once handled, no delete
concept exists either). The only genuine hard delete anywhere is
`reference_exchange_rates.removeIfPresent` (§1.12), and that table is
explicitly non-syncing device-local cache data (§10) -- it is not a
counter-example to "financial data is never hard-deleted," it's simply
not financial data.

**When hard deletion is allowed locally:** only for device-local,
regenerable, or pure-cache rows that never sync -- `reference_exchange_rates`
today, and, by the same reasoning, any future purely-local sync-engine
bookkeeping table (a pending-mutation queue, a pull cursor) CP12.3
introduces. **Never** for any table in §1.1-§1.11.

**When a syncable record requires a tombstone instead of a hard delete:**
always, for every table that currently soft-deletes, plus `categories`
once a delete path is built, plus (if ever exercised) `transaction_exchange_rates`
-- immutable historical facts are never hard-deleted even when "deleted"
in the ordinary UI sense; the delete itself becomes a recorded fact via
`deleted_at`, never an erasure. `recurring_occurrences` has no delete
concept today and V1 sync does not need to invent one -- there is
currently no product requirement to delete a handled occurrence, so no
tombstone shape is designed for it here.

**How `deleted_at` participates in sync:** identically to any other
field mutation, through the same envelope (§4) -- a delete is simply a
push whose payload sets `deleted_at` (with the record's `sync_version`
bumped, exactly like any other edit). There is no separate "delete
message" type needed.

**How another device learns a record was deleted:** the same pull path
every other change arrives through (§7) -- a pulled record with a
non-null `deleted_at` is applied locally via the exact same `deleted_at`
column write the local `softDelete` methods already use, so every
existing read path (which already filters `deleted_at IS NULL`, §2 point
6) automatically stops showing it, with zero new query logic.

**How resurrection is prevented:** a tombstoned record's `server_revision`
keeps advancing like any other record's -- a pull always applies
whatever the server currently holds for that id, including a `deleted_at`
value, and the local apply path must never special-case "if it's a
delete, ignore it" or "if I have local edits queued, skip the delete."
The general conflict rule (§5: server-accepted wins, delete-vs-edit
favors the delete for tables where a delete is behaviorally terminal)
already prevents an edit from reviving a deleted row after the fact.

**How long tombstones need to remain, for V1:** indefinitely. There is no
retention/purge policy to design in CP12.1 (the checkpoint's own
instruction: do not implement retention policies yet unless already
documented -- none is). A tombstoned row simply stays a row, forever,
exactly as it already does locally today; this is not a new cost sync
introduces, since local soft-delete already keeps every deleted row
physically present.

**How account deletion differs from ordinary record deletion:** ordinary
record deletion is scoped to one row and reversible in spirit only in
that the tombstone is a normal, permanent fact (never truly reversible,
since nothing un-deletes). Account (cloud identity) deletion is a
different, larger action entirely -- it must eventually delete or
tombstone *every* record `owner_user_id` touches, is almost certainly
subject to a legal/privacy deletion-request timeline (§9), and is not
something any of CP12.1's existing per-record mechanics automatically
provide just by being applied repeatedly. This document does not design
that flow (it belongs to CP12.2's identity work plus CP13's privacy/security
work), but flags explicitly that it is a distinct, harder problem that
must be designed deliberately, not assumed to fall out of per-record
tombstoning for free.

---

## 7. Push / pull / retry contract

**Governing rule, restated from the checkpoint brief and already true of
every local write path audited in §1**: the UI never waits on network
success to preserve a valid local financial edit. Every existing write
method (`recordExpense`, `postOccurrence`, `addContribution`, etc.)
already commits to the local Drift database synchronously (from the
caller's point of view) with no network step in the critical path at all
-- there is no network code anywhere in this codebase today (confirmed:
no `http`/`dio` package dependency exists, §"pubspec audit" below). Sync
is additive: a background layer that notices a local write happened
(via `sync_version`/`sync_status`, once those have real semantics, §1.14)
and pushes it, independently of whether the original UI call is still on
screen.

**Minimal V1 lifecycle** (this is the audited-then-chosen design, not a
generic template):

1. Local mutation commits (already true today, unchanged).
2. The same local write marks the row `sync_status = 'pending'` and bumps
   `sync_version` -- ideally inside the *same* Drift statement/transaction
   the mutation itself uses, so there is no window where a committed
   mutation is invisible to the sync engine.
3. A durable local **mutation queue** (new, local-only, never syncs
   itself -- §10) records `(entity_type, record_id, client_mutation_id,
   attempted_at)` for every pending row, so a killed/restarted app
   rebuilds exactly what still needs pushing from the queue plus the
   `sync_status` columns, never by re-scanning every table for "does this
   look unsynced" heuristically.
4. **Push**: batched, ordered by `created_at` within an entity type (never
   globally reordered across tables -- a `recurring_occurrences` row that
   references a `transactions` row created in the same batch must push
   in an order the server can satisfy referentially, or the server API
   must accept a batch and resolve intra-batch ordering itself; either is
   viable, decided at CP12.4, not here). Each mutation carries its
   `client_mutation_id` (idempotent retry, §4) and the `server_revision`
   it was last built against (conflict detection, §5).
5. **Server idempotently accepts or rejects**, per §5/§8's rules -- never
   a silent partial application of one logical mutation.
6. **Acknowledgement** updates the local row's `sync_status` to `'synced'`
   and records the new `server_revision`; a rejection (conflict) sets
   `sync_status` to a distinct `'conflict'` state and leaves the local
   data untouched for the user/CP12.2+ UI to resolve -- never auto-retries
   a rejected-for-conflict mutation blindly.
7. **Pull**: cursor-based (§4's `server_revision`, or a server-issued
   opaque cursor -- decided at CP12.4), "give me everything changed since
   cursor X," applied transactionally per batch: either a whole pulled
   batch commits locally or none of it does, so a crash mid-apply can
   never leave, say, a `recurring_occurrences` row referencing a
   `transactions` row that didn't make it into the same local commit.
8. Local state returns to clean (no pending mutations, cursor advanced)
   only once both push and pull for that cycle have fully settled.

**Retry/backoff**: exponential backoff with a cap, triggered by network
failure or a 5xx-equivalent server response -- never a fixed tight retry
loop. A rejection for a genuine conflict (§5) is not retried automatically
at all; only transient failures are.

**Offline queue behavior**: unbounded in practice (bounded only by local
disk, same as the rest of the local database) -- there is no "sync
queue full, drop oldest" policy, because dropping a financial mutation
silently is unacceptable (§0/§2).

**Crash/restart recovery**: the queue (step 3) plus each row's own
`sync_status`/`sync_version` together are the only state that matters --
both already live in the durable local Drift database, so a crash at any
point before "acknowledgement recorded" simply means the mutation is
retried on next launch, and a crash mid-pull-apply is recovered by the
transactional-apply guarantee in step 7 (the partially-applied batch
never committed, so it's simply re-pulled from the same cursor).

**Partial batch failure**: if the server rejects some mutations in a
pushed batch and accepts others, each is acknowledged/rejected
individually (§5's per-record conflict handling) -- never an all-or-nothing
batch outcome for *push* (that would force retrying already-accepted
mutations, risking the exact double-post problem §2 point 8 exists to
prevent). *Pull* application, by contrast, is all-or-nothing per batch
(step 7) precisely because pulled data has no "retry the one that
failed" concept as clean as push's client-mutation-id mechanism -- it is
simpler and safer to just re-pull the same batch from the same cursor.

**Duplicate request handling**: entirely `client_mutation_id`'s job (§4),
already covered.

---

## 8. Backend / server contract (conceptual only -- FastAPI + PostgreSQL, not implemented)

Endpoint shapes, at the conceptual level the checkpoint asked for:

- **Auth/session boundary**: issues and validates whatever session/token
  mechanism CP12.2 designs; every other endpoint below requires a valid
  session and derives `owner_user_id` from it -- **never from any field in
  the request body**. This is the single most important server-side rule
  in this whole document: a client that could set its own `owner_user_id`
  could read or overwrite another user's financial data by simply editing
  a JSON field, and no amount of client-side validation can be trusted to
  prevent that server-side.
- **Push mutations** (`POST /sync/mutations` or similar): accepts a batch
  of envelopes (§4). For each: validates the payload shape against
  `entity_type`, re-runs the same domain invariants §2 lists (positive
  amount, currency match, type immutability, etc. -- **the server must
  enforce every one of these independently of the client**, exactly the
  same "don't trust the UI alone" precedent ADR-019/021/022/023 already
  established for the *local* repository layer, now extended to the
  network boundary), checks `client_mutation_id` for idempotent replay,
  checks `server_revision` for conflict, and either commits + returns a
  new `server_revision`, returns the already-recorded result for a
  replayed `client_mutation_id`, or returns a structured conflict
  response carrying the current server state.
- **Pull changes since cursor** (`GET /sync/changes?since=<cursor>` or
  similar): returns every record with `owner_user_id` equal to the
  caller's session identity that changed after `since`, plus a new
  cursor. Ownership enforcement is identical to push: filtered by the
  session's identity server-side, never by a client-supplied user id.
- **Account deletion** (`POST /account/delete` or similar): a distinct,
  more consequential endpoint from ordinary record mutation (§6) --
  requires its own explicit confirmation step (decided at CP12.2, not
  designed here) and eventually tombstones/removes every record the
  identity owns, subject to whatever retention/legal timeline CP13/product
  decides.

**Request/response responsibilities, restated:** the client's job is to
package a locally-valid mutation with the right envelope fields and retry
transiently-failed pushes; the server's job is to be the final,
untrusted-client-proof authority on validation and ownership, and to be
the tie-breaker for conflicts. Cursor/revision semantics: `server_revision`
is a strictly increasing value the server controls per record (and a pull
cursor is a strictly increasing checkpoint over the server's own change
log) -- the client never invents or predicts either.

**Explicitly not part of this or any near-term backend contract** (per
the checkpoint's own exclusion list, restated so this document doesn't
scope-creep by omission): bank integration, AI, OCR, household/shared-wallet
sync, real-time collaborative editing, remittance, trading, event
sourcing as a general architecture (the mutation-queue-plus-cursor design
above is deliberately simpler than full event sourcing -- it needs no
event replay/rebuild-state-from-events capability for V1).

---

## 9. Security / privacy boundary (requirements only -- CP13 implements)

- **TLS is required** for every network call this feature ever makes;
  there is no scenario where plaintext HTTP is acceptable for financial
  data or session tokens.
- **Token/session storage boundary**: never in the Drift database (which
  is what eventually syncs, §10), never logged, never in a synced table --
  platform secure storage only (the exact mechanism is a CP13 decision).
- **Server authorization**: restated from §8 -- every request is
  authorized against the session's own identity, never a client-supplied
  id.
- **Least-data collection**: the identity contract in §3 deliberately
  collects nothing beyond a stable id and (eventually) whatever the
  chosen auth provider minimally requires -- no unnecessary PII fields are
  introduced by this design.
- **No full card PAN/CVV/PIN, ever.** Consistent with the existing product
  direction (`20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §1.3 already
  states a debit card stores only a masked last-4 identifier, never a full
  card number) -- sync must never be the mechanism that accidentally
  introduces a full-PAN field somewhere down the line.
- **Deletion/export compatibility**: the tombstone contract (§6) and the
  per-`owner_user_id` pull query (§8) together are exactly what a future
  "export my data" or "delete my account" feature needs to enumerate a
  user's full record set -- this document's design does not block that,
  and CP13/product should build export/delete on top of the same
  ownership query, not a parallel one.
- **Logging/redaction**: sync engine logs (push/pull attempts, retries,
  conflicts) must never log a full transaction payload (amount + note +
  account) at anything above debug-level-in-a-dev-build; production
  logging should log ids/status/timing only.
- **Secrets never committed to the repo**: no API keys, no backend
  connection strings, no signing secrets in this codebase or its docs --
  a CP13/CP12.4 concern for whatever config-injection mechanism the
  FastAPI backend uses, not touched by this audit.
- **Environment/config separation**: dev/staging/prod backend endpoints
  must be switchable via build configuration, never hardcoded into a
  single URL constant that would make a debug build accidentally talk to
  production data.

---

## 10. What must NOT sync

| Data | Verdict | Why |
|---|---|---|
| `reference_exchange_rates` (cached current FX quotes) | **Device-local** | Explicitly a replaceable, freshness-based cache with zero connection to any transaction (§1.12); syncing it would also risk it being mistaken for authoritative transaction FX, which §2 point 7/11 forbids outright. Each device should simply re-fetch/re-cache its own copy from the live provider. |
| Notification scheduling artifacts (OS notification ids) | **Recompute** | Never persisted even locally (§1.13) -- deterministically derived from `recurring_rules`/`recurring_occurrences`, which DO sync; the derived ids themselves are meaningless outside the OS scheduler that issued them and must be recomputed fresh on every device. |
| Transient UI state (Activity screen search/filter) | **Device-local** | `activityFilterProvider` is an `autoDispose` Riverpod provider with no persistence at all, by construction (§1.13) -- there is nothing to sync; it doesn't outlive even a single local session. |
| Theme preference | **Device-local (for V1)** | Purely decorative, explicitly documented as "never read by any money/accounting/currency/FX/recurring/goals/budget logic" (`profiles.theme_preference`'s own doc comment). Could sync later as a low-stakes preference (§5's "safe to auto-merge" category) but there's no product requirement forcing it into V1 scope. |
| Language preference | **Device-local (for V1)** | Same reasoning as theme -- a per-device display preference, not a financial concern, not required to sync for V1's stated scope (money capture, balances, budgets, goals, recurring, history). |
| Currency-converter favorite pairs | **Device-local** | Already explicitly documented as session-only, in-memory (ADR-028) -- not durable even locally today; nothing for sync to carry. |
| Local reminder/notification ids | **Recompute** | Same as scheduling artifacts above -- `NotificationIdAllocator` guarantees the same *input* (rule + date) always deterministically allocates a valid id again on any device; there is nothing stateful to transmit. |
| Derived account balances | **Recompute** | Never stored anywhere (§2 point 5) -- `FinanceEngine` computes them from `accounts.opening_balance_minor_units` plus synced `transactions` rows every time; syncing a "balance" field would create a second, contradictable source of truth that doesn't exist today and must not be invented for sync's sake. |
| Generated/derived subscription estimates | **Recompute** | `computeSubscriptionEstimatedTotals`/`RecurringEstimate` are pure functions of already-synced `recurring_rules` data (ADR-031) -- nothing about a subscription's estimated monthly/yearly figure is ever stored; every device recomputes it identically from the same synced rule. |
| `currencies` seed table | **Recompute (code-embedded, not user data)** | Fixed `CurrencyRegistry.seed` constant, identical on every install by construction (§1.1) -- not user data at all, never needs a network round-trip. |
| System (`is_system = true`) categories | **Recompute (code-embedded, not user data)** | Same reasoning as currencies -- a fixed, shared seed list (§1.3), not something any individual user owns or edits. |
| Local sync-engine bookkeeping (mutation queue, pull cursor, device/install id) | **Device-local** | This is the sync engine's own operational state (§7/§3.2) -- syncing it would be circular (state *about* syncing does not itself need to sync) and it is meaningless on a different device, which needs its own cursor/queue anyway. |

---

## 11. Migration / compatibility audit

**Will V1 sync require a Drift schema migration? Yes, but a small,
additive one -- go decision: proceed, with the specific additive changes
below, none of which touch existing data shape or existing columns.**

| Table | Field/index/constraint | Reason | Backfill | Compatibility |
|---|---|---|---|---|
| `categories` | add `created_at`, `updated_at` (`DateTimeColumn`, not nullable) | Every other syncable table already has both; sync needs them to order/timestamp category mutations the same way as every other entity. | Backfill every existing row's `created_at`/`updated_at` to the migration's own run time (there is no earlier authentic timestamp to recover -- the same "no historical data existed before this column existed" situation `theme_preference`'s v6 migration already handled). | Additive only; no existing column changes shape; `CategoryRepository`'s existing read/write paths are unaffected until they're deliberately updated to populate these. |
| `categories` | add `deleted_at` (`DateTimeColumn`, nullable) | No delete path exists at all today (§1.3) -- sync needs a tombstone mechanism before a category can ever be safely deleted across devices. | `NULL` for every existing row (nothing is deleted yet). | Additive; every existing read path in `CategoryRepository` already has no `deleted_at` filter to break, since none exists yet -- this migration and the repository-layer work to actually filter/write it are two separate, sequenced steps (schema first, behavior in CP12.3+). |
| `categories` | add `sync_version` (`IntColumn`, default `0`), `sync_status` (`TextColumn`, default `'localOnly'`) | Bring this table in line with every schema-v2-onward table's existing placeholder pair (§1.14). | Every existing row defaults to `0`/`'localOnly'`, identical to how every other table's existing rows already sit. | Additive; matches the established v2+ precedent exactly, so this is the least risky migration in this list. |
| `accounts` | add `sync_version` (`IntColumn`, default `0`), `sync_status` (`TextColumn`, default `'localOnly'`) | `accounts` is the only other financial table missing this pair (§1.4) -- everything created from schema v2 onward already has it. | Same as above. | Additive; no existing column changes shape. |
| `transaction_exchange_rates` | add `created_at`, `updated_at`, `deleted_at`, `sync_version`, `sync_status` | Bring this dormant table up to the same shape as every other table, **only if/when it is actually wired into a live feature** -- there is no urgency while it holds zero production rows (§1.11). | N/A while empty; trivial backfill if ever needed. | Additive; genuinely zero risk while unused, so this can be deferred past CP12.1-12.7 without blocking V1 sync of the tables that actually matter. |

**Everything else in §1 already has the shape sync needs.** In
particular, `sync_version`/`sync_status`'s *semantics* (§1.14) need real
application logic, not a schema change -- reusing the existing columns'
existing names/types for that logic requires no migration at all.

**Do current IDs survive offline creation -> cloud upload -> another
device download, without remapping? Yes, for every table audited in §1,
with one caveat already flagged:**

- Every table's primary key is a client-generated `Uuid().v4()` (or, for
  `reference_exchange_rates`, a composite natural key that never needs to
  sync at all, §10) -- generated once, locally, at creation time, and never
  regenerated or remapped by any repository method audited above. A UUIDv4
  collision between two independently-offline devices is astronomically
  unlikely and is the standard justification every offline-first system
  relies on for this exact scheme.
- The one caveat: `categories`' eight seeded system rows use **fixed
  string ids** (`"sys-groceries"`, etc.), not UUIDs. This is safe today
  only because the seed list is a hardcoded Dart constant, identical on
  every install -- it must stay that way (never let a future edit
  introduce a *different* fixed id for the *same* conceptual system
  category on some future app version, which would silently create a
  second "same" category with a different id across devices/versions).
  This is a discipline requirement on future code changes, not a schema
  migration.

**This is the go/no-go answer the checkpoint asked for: GO.** No ID
scheme in the current schema blocks V1 sync; the ID design was already
offline-first from Beta 0 (the `uuid` package dependency's own comment in
`pubspec.yaml` says so explicitly: *"Client-generated IDs for
offline-first writes"*). The migrations above are small, additive, and
low-risk precisely because the hard part -- ID generation -- was already
done correctly before this audit.

---

## 12. Failure-mode review

| Scenario | Expected safe behavior |
|---|---|
| App killed during push | On restart, the mutation queue (§7 step 3) plus each row's `sync_status` still show it as pending -- the push is simply retried. `client_mutation_id` guarantees this is safe even if the server actually received and accepted the request before the kill (§4/§7's idempotent-replay guarantee). |
| App killed while applying a pull | The transactional-apply guarantee (§7 step 7) means either the whole pulled batch committed before the kill (safe, cursor already advanced) or none of it did (safe, re-pull from the same unchanged cursor on restart) -- never a half-applied batch. |
| Network drops after server accepted a mutation but before the client receives the ACK | The client still holds the row as `pending`/retries the push; the retry carries the same `client_mutation_id`, so the server recognizes it as already-accepted and returns the original acknowledgement rather than double-applying it. |
| Same mutation retried (any reason) | No-op beyond re-delivering the original acknowledgement -- `client_mutation_id` (§4/§7). |
| Two devices edit the same transaction offline | Both queue locally; whichever reaches the server first (by `server_revision`) is accepted; the second is rejected as a conflict and surfaced to the user rather than silently overwritten or auto-merged (§5). |
| One device deletes a record while another edits it (offline, same record) | Delete wins for tables where deletion is behaviorally terminal today (`accounts`, `recurring_rules`, `savings_goals`, `budgets`, `transactions` -- every one of them already treats "deleted" as excluding the row from every further read/write path, §2 point 6) -- the edit is discarded and surfaced, never silently applied to a tombstoned row (§5/§6). |
| Server returns malformed/invalid money data | Rejected client-side before ever reaching a Drift write -- the same validation `Money`/repository constructors already perform locally (positive-amount checks, currency-registry lookups, `CurrencyMismatchException`, etc., §2) must run again on data coming *from* the server during pull-apply, not only on data going *to* it during push. A malformed pulled record is logged and skipped, never partially applied. |
| Server sends an unknown enum/currency | Rejected/skipped the same way, not crashed on -- `CurrencyRegistry.require` already throws a clear `ArgumentError` for an unknown code locally; the pull-apply path must catch that class of error per-record (so one bad record doesn't abort an entire pull batch) and flag it for investigation rather than silently coercing it to a guessed value. |
| Local schema older than the server's payload shape | The client must recognize and refuse (or safely ignore unknown fields of) a payload shape newer than its own migration level, never attempt to write a field its local schema doesn't have -- this is exactly why `entity_type` + an explicit schema/shape version belongs in the eventual wire contract (a refinement of §4's envelope, decided in detail at CP12.4), so a client can tell "I don't understand this yet" from "this is valid and I should apply it." |
| User signs out with pending local mutations | Nothing is discarded (§0/§3.4) -- the mutations remain queued locally exactly as an offline queue would; signing back in (to the *same* account) resumes pushing them normally. |
| User signs into a **different** cloud account on the same device | This is the one case needing an explicit, deliberate product decision this document does not make unilaterally: pending mutations queued under the *previous* account must never be pushed under the new account's identity (that would corrupt ownership). Safe default: refuse to switch accounts while local mutations are still pending for the previous one, prompting the user to let sync finish first -- deferred to CP12.2 for the exact UX, but the invariant ("never push account A's queued mutation as account B") is non-negotiable regardless of which UX is chosen. |
| User reinstalls the app | All local data is lost (confirmed in §3.4 -- this is today's actual behavior, not hypothetical); signing back in on the fresh install triggers a full pull that reconstructs local state from the server. Until that first pull completes, the local app is in the same "no data yet" state as a genuinely new user -- never a false empty state presented as if it were a legitimate empty account. |
| Server unavailable for several days | Every local feature keeps working (§0) -- the mutation queue simply grows (bounded only by local disk, §7) and retries with backoff; nothing about the app degrades locally just because sync hasn't succeeded recently. Once the server returns, the queue drains in the ordering §7 already defines. |

---

## 13. Release / test gates (for CP12.2+ implementation, defined now so they're testable, not vague)

- **Local-first/offline operation**: every existing local repository test
  (`test/core/database/repositories/*`) must continue passing completely
  unmodified with sync code present but the network/server absent --
  proof that sync is additive, not load-bearing.
- **No lost mutations**: a test that kills the (simulated) app process at
  every step of the push lifecycle (queued, mid-push, ACK received) and
  asserts the mutation is still present, exactly once, in the queue or
  applied server-side, after restart.
- **Retry idempotency**: pushing the same `client_mutation_id` N times (in
  a test, simulate 2, 5, and 50) must produce exactly one server-side
  effect and N identical acknowledgements.
- **Duplicate-create protection**: two simulated devices creating a
  budget for the same `(profile, category, currency, year, month)` key
  offline, then both syncing, must result in exactly one active row for
  that key server-side and locally on both devices after the second
  device's next pull.
- **Tombstone propagation**: a delete on device A must be visible as
  `deleted_at`-set on device B within one pull cycle, with device B's
  local read paths (already filtering `deleted_at IS NULL`, §2) correctly
  hiding it with zero new query code.
- **No resurrection**: a simulated race where device A deletes a record
  while device B has a stale, older edit queued for the same record must
  never result in the record reappearing active after both sync.
- **Conflict behavior**: a test matrix covering every "concurrent edit"
  row in §5's table, asserting the specified winner and that the loser's
  data is preserved somewhere retrievable (never silently discarded, per
  §5's core rule) even though it did not become canonical.
- **Exact money round-trip**: a transaction with an amount at the edges of
  realistic magnitude, in a 0-decimal currency (JPY) and a 3-decimal
  currency (KWD), must push and pull back with `amount_minor_units`
  bit-for-bit identical -- no floating-point involvement anywhere in the
  wire path (§2 point 1).
- **Transfer invariants**: a synced transfer must still fail
  `CurrencyMismatchException` server-side if pushed with mismatched
  account currencies, exactly as the local repository already rejects it
  (§2 point 4) -- proving server-side re-validation actually runs, not
  merely client-side.
- **Recurring idempotency**: two simulated devices independently posting
  the same rule's same `scheduled_date` offline must result in exactly one
  `transactions` row and one `recurring_occurrences` row after both sync
  (§2 point 8, §5).
- **Goal contribution idempotency**: the same retried "add contribution"
  push must never create a second contribution row.
- **Crash recovery**: kill/restart at every stage of both push and pull
  (already covered narratively in §12) as an automated, repeatable test
  matrix, not just a design claim.
- **Account-switch isolation**: switching signed-in accounts must never
  push a pending mutation under the wrong `owner_user_id` (§12's explicit
  non-negotiable invariant) -- test by attempting exactly that and
  asserting it's refused.
- **Malformed server payload rejection**: a deliberately corrupted pull
  response (bad enum, non-integer amount, unknown currency) must be
  rejected per-record without aborting the rest of the batch and without
  ever reaching a Drift write (§12).
- **Multi-device deterministic tests**: the same simulated mutation
  sequence, replayed in a different device-arrival order, must converge
  to the identical final server + local state every time -- determinism
  is the property that makes all of the above gates trustworthy rather
  than merely "usually passes."

---

## 14. Roadmap CP12.2 - CP12.7

The checkpoint's proposed shape is well-matched to this audit's findings
and is adopted as-is, with the audit's own specific findings folded into
each step's scope:

- **CP12.2 Identity/Auth foundation** -- implements §3: the cloud identity
  concept, the local-profile-to-cloud-user link, session boundary, and the
  explicit account-switch-with-pending-mutations decision §12 flags as
  needing a real UX (not just an invariant).
- **CP12.3 Local sync state + mutation queue** -- implements the
  *semantics* half of §1.14/§4/§7: gives `sync_version`/`sync_status` real
  meaning, builds the durable local mutation queue, and applies the four
  additive schema migrations §11 specifies (`categories`'
  `created_at`/`updated_at`/`deleted_at`/`sync_version`/`sync_status`,
  `accounts`' `sync_version`/`sync_status`). This step touches schema and
  is exactly the kind of "no code changes unless absolutely necessary"
  work CP12.1 deliberately deferred rather than doing prematurely.
- **CP12.4 Backend sync API + PostgreSQL persistence** -- implements §8:
  the FastAPI endpoints, the PostgreSQL schema mirroring §1/§4's record
  shapes (with server-side re-validation of every §2 invariant), and the
  exact cursor/batching/ordering decisions §7/§8 left open.
- **CP12.5 Push/pull engine + conflict/tombstone behavior** -- implements
  §5/§6/§7's full lifecycle end-to-end against the real backend from
  CP12.4.
- **CP12.6 Sync UI/offline/error/recovery** -- surfaces conflict
  resolution (§5), sync status, and retry/error states to the user;
  resolves the account-switch UX §12 deferred from CP12.2.
- **CP12.7 Hardening + multi-device QA** -- executes the full §13 gate
  suite against real multi-device scenarios, closes any gap the earlier
  steps' narrower unit-level testing didn't catch.

No step in this sequence changes V1 product scope -- every capability
audited in §1/§2 keeps working exactly as it does today, offline, for the
entire CP12.2-12.7 sequence, until the day sync is actually turned on for
a given user.

---

## Appendix: pubspec audit (supporting §7/§9's "no network code exists yet" claims)

Direct dependency list (`pubspec.yaml`) as of HEAD `2171f82`: `flutter`,
`flutter_localizations`, `flutter_riverpod`, `go_router`, `drift`,
`sqlite3_flutter_libs`, `sqlite3`, `path_provider`, `path`, `uuid`,
`intl`, `decimal`, `meta`, `flutter_local_notifications`, `timezone`,
`flutter_timezone`, plus dev-only `flutter_test`, `build_runner`,
`drift_dev`, `flutter_lints`. **No HTTP client (`http`/`dio`), no auth
package, no Firebase/backend-SDK package, and no device-info package
exist anywhere in this dependency list.** CP12.1 is therefore auditing a
codebase with genuinely zero pre-existing networking/cloud/identity
infrastructure -- every recommendation in §3/§4/§8/§9 is a from-scratch
design, not a retrofit of something partially built.
