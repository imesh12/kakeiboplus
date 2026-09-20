import 'package:drift/drift.dart';

/// Drift schema version 1 (Beta 0). Scope and rationale are documented in
/// `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §6 and
/// `docs/14_DECISION_LOG.md` ADR-020.
///
/// Naming note: every table below that would otherwise generate a data
/// class colliding with a domain type already defined elsewhere in the
/// app (`lib/core/currency/currency.dart`'s `Currency`, and the
/// `Profile`/`Account`/`Category` types Beta 0's feature layer defines)
/// is given an explicit `@DataClassName('...Row')` so the generated
/// Drift row type and the app's own domain type can both be imported in
/// the same file without ambiguity. Repositories are what map between
/// the two — see `lib/features/*/data/*_repository.dart`.

@DataClassName('CurrencyRow')
class Currencies extends Table {
  /// ISO 4217 alphabetic code, e.g. "JPY", "KWD". Primary key.
  TextColumn get code => text()();
  TextColumn get displayName => text()();
  TextColumn get symbol => text()();

  /// Number of digits after the decimal point — see
  /// `lib/core/currency/currency.dart`. Never assume 2.
  IntColumn get minorUnits => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{code};
}

@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();

  /// ISO 3166-1 alpha-2 country code.
  TextColumn get homeCountry => text()();
  TextColumn get currentCountry => text()();
  TextColumn get homeCurrency => text().references(Currencies, #code)();
  TextColumn get livingCurrency => text().references(Currencies, #code)();
  TextColumn get preferredLanguage => text()();
  TextColumn get timezone => text()();
  TextColumn get dateFormat => text()();
  TextColumn get numberFormat => text()();

  /// Checkpoint 8.1 (Premium Theme Personalization Foundation): the
  /// user's chosen decorative product theme -- one of
  /// `AppThemeStyle.storageValue` ('light'/'dark'/'pink'/'ocean'/
  /// 'forest'). Defaulted to `'light'` (schema v6 migration backfills
  /// every existing row to `'light'`, matching `AppThemeStyle.fallback`
  /// exactly, so no existing install's appearance changes on upgrade).
  /// Purely a UI-presentation preference: never read by any money/
  /// accounting/currency/FX/recurring/goals/budget logic, and reading
  /// it back always goes through `AppThemeStyle.fromStorageValue`,
  /// which never throws for a missing/unknown/corrupt value -- see that
  /// factory's own doc comment.
  TextColumn get themePreference => text().withDefault(const Constant('light'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();

  /// Null for a system category (seeded, shared across profiles).
  TextColumn get profileId => text().nullable().references(Profiles, #id)();

  /// Self-reference for subcategories. Deliberately declared WITHOUT a
  /// `.references()` foreign-key helper (unlike the other FKs in this
  /// file) — Beta 0 doesn't build a subcategory UI, so this column isn't
  /// exercised yet, and keeping it a plain nullable column avoids taking
  /// on an unverified self-referencing-table code path in the generator
  /// for a feature that isn't built. Referential integrity for it is an
  /// application-layer concern until subcategories are implemented.
  TextColumn get parentId => text().nullable()();

  /// 'expense' | 'income' | 'both'
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();

  /// 'cash' | 'bank' | 'card' | 'wallet' | ... — free-form for Beta 0,
  /// validated at the UI layer rather than a DB CHECK constraint.
  TextColumn get type => text()();
  TextColumn get currencyCode => text().references(Currencies, #code)();

  /// Money, stored as integer minor units — see ADR-017. Never a REAL
  /// column.
  IntColumn get openingBalanceMinorUnits => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class Transactions extends Table {
  /// Client-generated UUID (v4) — see `docs/03_DATABASE_SCHEMA.md`.
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The source account for every type; for a transfer this is where
  /// money leaves from.
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Set only for `type == 'transfer'` — the account money moves into.
  /// Beta 0 enforces (at the repository layer, not a DB constraint) that
  /// this account shares `currencyCode` with `accountId` — see ADR-019.
  TextColumn get destinationAccountId => text().nullable().references(Accounts, #id)();

  /// One of `TransactionType.name` — see
  /// `lib/core/finance/transaction_type.dart`. Stored as text rather
  /// than through a Drift `TypeConverter` to keep the generated schema
  /// simple; the enum<->string mapping lives in the repository layer.
  TextColumn get type => text()();

  /// Money, stored as integer minor units — see ADR-017. Always a
  /// positive magnitude; direction comes from `type`.
  IntColumn get amountMinorUnits => integer()();
  TextColumn get currencyCode => text().references(Currencies, #code)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();

  /// Stored in UTC — see `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §10.
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete. Forward-compatible per ADR-020 — inert until Stage 6.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Forward-compatible per ADR-020 — inert until Stage 6 (cloud/sync).
  /// Beta 0 always writes 0 / "localOnly" and never reads these outside
  /// of that constant.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A monthly budget -- either an overall (whole-currency) budget or a
/// category budget, discriminated by [categoryId]'s nullability. See
/// `docs/14_DECISION_LOG.md` ADR-021 and
/// `lib/features/budgets/domain/budget_month.dart`.
@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Null for an overall (whole-currency) monthly budget; set to a
  /// `Categories.id` for a category budget. A single table serves both
  /// budget kinds, discriminated by this column's nullability -- the
  /// same pattern `Transactions.destinationAccountId` already uses to
  /// distinguish a transfer from every other transaction type.
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  TextColumn get currencyCode => text().references(Currencies, #code)();

  /// Structured year/month -- never a floating "current month" concept
  /// or a parsed `YYYY-MM` string. See
  /// `lib/features/budgets/domain/budget_month.dart`.
  IntColumn get year => integer()();
  IntColumn get month => integer()();

  /// Money, stored as integer minor units — see ADR-017. Always
  /// strictly positive; `BudgetRepository` rejects a zero or negative
  /// amount before it ever reaches this table (see ADR-021).
  IntColumn get amountMinorUnits => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete — same convention as `Accounts`/`Transactions`.
  /// `BudgetRepository` enforces "at most one active row per
  /// profile/currency/year/month(/categoryId)" at the application layer,
  /// not via a DB constraint (see ADR-021, following ADR-019's
  /// precedent). This column is what "active" means (`deletedAt IS
  /// NULL`), and is specifically what lets a budget be recreated after
  /// deletion without conflicting with its own soft-deleted predecessor.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Forward-compatible per ADR-020's precedent — inert until Stage 6
  /// (cloud/sync). Beta 1 always writes 0 / "localOnly" and never reads
  /// these outside of that constant.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A savings goal — Beta 1 Task 3. See `docs/14_DECISION_LOG.md` ADR-022
/// and `lib/features/goals/domain/`.
///
/// [currencyCode] is permanently anchored at creation time and is never
/// changed by `SavingsGoalRepository.updateGoal` — see ADR-022. A goal's
/// target amount may only ever be updated in the SAME currency it was
/// created with; there is no FX conversion of a goal's target.
@DataClassName('SavingsGoalRow')
class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Trimmed, non-empty — `SavingsGoalRepository` rejects an empty or
  /// whitespace-only name before it ever reaches this table (ADR-022).
  TextColumn get name => text()();

  /// Money, stored as integer minor units — see ADR-017. Always
  /// strictly positive; `SavingsGoalRepository` rejects a zero or
  /// negative amount before it ever reaches this table.
  IntColumn get targetAmountMinorUnits => integer()();

  /// Permanently anchored at creation — see ADR-022. Never changed by
  /// `updateGoal`; a currency change is rejected with
  /// `CurrencyMismatchException`.
  TextColumn get currencyCode => text().references(Currencies, #code)();

  /// Optional calendar date (year/month/day only — no meaningful
  /// time-of-day component), normalized via
  /// `normalizeCalendarDateToUtc` in
  /// `lib/features/goals/domain/goal_target_date.dart`. Deliberately
  /// NOT a genuine instant — see that file's doc comments for why this
  /// column is never produced via `DateTime.toUtc()`.
  DateTimeColumn get targetDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete — same convention as `Accounts`/`Transactions`/
  /// `Budgets`. Per ADR-022, a soft-deleted goal's contribution rows are
  /// NOT cascade-deleted (they remain physically present for potential
  /// future history/export), but `SavingsGoalContributionRepository` and
  /// the calculation/detail providers refuse to treat a soft-deleted
  /// goal as active — see `lib/features/goals/domain/` and
  /// `lib/features/goals/presentation/savings_goal_providers.dart`.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Forward-compatible per ADR-020's precedent — inert until Stage 6
  /// (cloud/sync). Beta 1 always writes 0 / "localOnly" and never reads
  /// these outside of that constant.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// An explicit, append-only contribution ledger entry toward a
/// [SavingsGoals] row — Beta 1 Task 3. See `docs/14_DECISION_LOG.md`
/// ADR-022. Deliberately does NOT create a `Transactions` row — a
/// contribution has no income/expense/transfer side effect (ADR-022).
@DataClassName('SavingsGoalContributionRow')
class SavingsGoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(SavingsGoals, #id)();

  /// Money, stored as integer minor units — see ADR-017. Always
  /// strictly positive; `SavingsGoalContributionRepository` rejects a
  /// zero or negative amount before it ever reaches this table. There is
  /// no negative/"withdrawal" contribution in Beta 1 (ADR-022).
  IntColumn get amountMinorUnits => integer()();

  /// Duplicated from the parent goal's `currencyCode` at write time
  /// (rather than derived via a join) — see ADR-022 for the tradeoff
  /// rationale. `SavingsGoalContributionRepository` enforces this must
  /// match the parent goal's currency, and that the parent goal is
  /// active (not soft-deleted), before insert.
  TextColumn get currencyCode => text().references(Currencies, #code)();

  /// A genuine instant, always stored as a UTC `DateTime` — see
  /// `SavingsGoalContributionRepository.addContribution`'s
  /// `contributedAt` parameter. Unlike `SavingsGoals.targetDate` (a
  /// calendar-only date), this column IS produced via `.toUtc()`,
  /// because a contribution really did happen at a specific instant.
  DateTimeColumn get contributedAt => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  /// Soft delete — same convention as `Accounts`/`Transactions`/
  /// `Budgets`/`SavingsGoals`. Beta 1 supports deleting a contribution
  /// but not editing one (ADR-022).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Forward-compatible per ADR-020's precedent — inert until Stage 6
  /// (cloud/sync). Beta 1 always writes 0 / "localOnly" and never reads
  /// these outside of that constant.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A recurring schedule/template -- Beta 1 Task 4A. See
/// `docs/14_DECISION_LOG.md` ADR-023 and
/// `lib/features/recurring/domain/`. This table is a schedule only: it
/// never affects account balances, income/expense totals, budgets,
/// goals, or dashboard totals by itself -- only an explicitly posted
/// [RecurringOccurrences] row (which creates a real [Transactions] row)
/// does that. Nothing auto-posts a transaction from this table.
@DataClassName('RecurringRuleRow')
class RecurringRules extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// 'expense' | 'income' | 'transfer' -- see
  /// `lib/features/recurring/domain/recurring_rule_kind.dart`.
  TextColumn get kind => text()();

  /// Trimmed, non-empty label -- e.g. "Rent", "Salary".
  TextColumn get name => text()();

  /// Money, stored as integer minor units -- see ADR-017. Always
  /// strictly positive; `RecurringRuleRepository` rejects a zero or
  /// negative amount before it ever reaches this table.
  IntColumn get amountMinorUnits => integer()();
  TextColumn get currencyCode => text().references(Currencies, #code)();

  /// The one account for 'expense'/'income'; the SOURCE account for a
  /// 'transfer'. `RecurringRuleRepository` enforces this account's
  /// currency matches [currencyCode].
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Set only for `kind == 'transfer'` -- the destination account.
  /// `RecurringRuleRepository` enforces it differs from [accountId] and
  /// shares its currency (and [currencyCode]) -- cross-currency
  /// recurring transfers are rejected, same as
  /// `TransactionRepository.recordTransfer` (ADR-019).
  TextColumn get destinationAccountId => text().nullable().references(Accounts, #id)();

  /// Never set for a transfer (transfers are never categorized -- same
  /// convention as `Transactions.categoryId`).
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();

  /// 'daily' | 'weekly' | 'monthly' | 'yearly' -- see
  /// `lib/features/recurring/domain/recurrence_frequency.dart`.
  TextColumn get frequency => text()();

  /// Repeat every [interval] units of [frequency] -- e.g. `frequency:
  /// 'weekly', interval: 2` is "every 2 weeks". Always `>= 1`.
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// Calendar date only (year/month/day -- no meaningful time-of-day
  /// component), normalized via
  /// `lib/features/recurring/domain/recurring_schedule.dart`'s
  /// `normalizeRecurringDate` -- same "never `.toUtc()` a picked local
  /// date" reasoning as `SavingsGoals.targetDate`. Inclusive -- always
  /// the schedule's first occurrence.
  DateTimeColumn get startDate => dateTime()();

  /// Calendar date only, same normalization as [startDate]. Inclusive,
  /// if set -- the last calendar date an occurrence may fall on. `null`
  /// means the schedule never ends.
  DateTimeColumn get endDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete -- same convention as `Accounts`/`Transactions`/
  /// `Budgets`/`SavingsGoals`. A deleted rule is excluded from every
  /// active/upcoming provider and can never post a new occurrence again
  /// (`RecurringOccurrenceRepository.postOccurrence` requires an active
  /// rule); its already-posted `Transactions` rows and already-handled
  /// `RecurringOccurrences` rows are untouched.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Opt-in local reminder notifications for this rule -- Beta 1 Task
  /// 4B. Default `false` (schema v5 migration backfills existing rows
  /// to `false`, never retroactively opts anyone in). Purely a user
  /// preference: it never changes recurrence math, never auto-creates
  /// a `Transactions`/`RecurringOccurrences` row, and is read only by
  /// the notification-scheduling layer (see
  /// `lib/features/recurring/domain/recurring_reminder_planner.dart`
  /// and `lib/core/notifications/`) -- never by `RecurringSchedule` or
  /// any posting/skipping logic. See `docs/14_DECISION_LOG.md`
  /// ADR-024.
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Forward-compatible per ADR-020's precedent -- inert until Stage 6
  /// (cloud/sync). Beta 1 always writes 0 / "localOnly" and never reads
  /// these outside of that constant.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// One [RecurringRules] scheduled date that has actually been handled --
/// Beta 1 Task 4A. A *pending/due* occurrence is never a row here: it is
/// derived on the fly from a rule's schedule (see
/// `lib/features/recurring/presentation/recurring_providers.dart`). A
/// row only ever exists once the user posted or explicitly skipped that
/// scheduled date -- see `docs/14_DECISION_LOG.md` ADR-023.
///
/// `RecurringOccurrenceRepository` enforces, at the application layer
/// (same precedent as `BudgetRepository`'s one-active-row-per-key rule),
/// that at most one row exists per (`ruleId`, `scheduledDate`) pair --
/// posting or skipping an already-handled occurrence (in either status)
/// is rejected rather than creating a second row or silently
/// overwriting the first.
@DataClassName('RecurringOccurrenceRow')
class RecurringOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get ruleId => text().references(RecurringRules, #id)();

  /// The calendar date (year/month/day only) this occurrence is
  /// scheduled for -- normalized the same way as
  /// `RecurringRules.startDate`. Never rewritten after insert.
  DateTimeColumn get scheduledDate => dateTime()();

  /// 'posted' | 'skipped' -- see
  /// `lib/features/recurring/domain/recurring_occurrence_status.dart`.
  TextColumn get status => text()();

  /// Set if and only if [status] is 'posted' -- the real `Transactions`
  /// row this occurrence created via
  /// `RecurringOccurrenceRepository.postOccurrence`. Always `null` for a
  /// 'skipped' occurrence.
  TextColumn get transactionId => text().nullable().references(Transactions, #id)();

  DateTimeColumn get handledAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  /// Forward-compatible per ADR-020's precedent -- inert until Stage 6
  /// (cloud/sync).
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Reserved per ADR-020 / ADR-009 — the historical-FX-snapshot invariant
/// depends on this table's shape existing, but Beta 0 never writes to it
/// (no FX provider integration, live conversion, or rate fetching is
/// implemented yet). It stays empty until Stage 3.
class TransactionExchangeRates extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get baseCurrency => text()();
  TextColumn get quoteCurrency => text()();

  /// Full-precision decimal string — e.g. "153.482071". Deliberately
  /// TEXT, never REAL: exchange rates must never be rounded merely by
  /// virtue of how they're stored (ADR-018), and a REAL/double column
  /// would risk exactly that.
  TextColumn get rate => text()();

  /// The converted Money result, as integer minor units in
  /// [quoteCurrency] — this IS rounded per ADR-018 (ROUND HALF UP), at
  /// the point it was computed, before being stored here.
  IntColumn get convertedAmountMinorUnits => integer()();
  TextColumn get provider => text()();
  DateTimeColumn get providerTimestamp => dateTime()();
  DateTimeColumn get fetchedAt => dateTime()();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The CURRENT/reference exchange-rate cache — Checkpoint 9.3 (schema
/// v7). Persists `ReferenceFxRate`
/// (`lib/core/fx/reference_fx_rate.dart`) so `DriftReferenceFxRateCache`
/// survives an app restart; `InMemoryReferenceFxRateCache` remains
/// available for tests and any context a database isn't appropriate for
/// (see `lib/core/fx/reference_fx_rate_providers.dart`).
///
/// # Do not confuse this with [TransactionExchangeRates]
///
/// [TransactionExchangeRates] is an immutable historical fact permanently
/// attached to one specific transaction (ADR-009/ADR-010) — it is never
/// replaced, and this table is never joined to it, read from it, or
/// written from it. This table is a replaceable, refreshable,
/// freshness-based CURRENT market quote with no connection to any
/// transaction (ADR-011: "FX rates are reference data") — see
/// `lib/core/fx/reference_fx_rate.dart`'s own class doc for the same
/// separation stated from the domain-model side. Two independent
/// lifecycles, on purpose.
///
/// # Primary key — an intentional departure from this file's usual
/// surrogate-`id` convention
///
/// Every other table in this file uses a surrogate `TextColumn id` as its
/// primary key, even where an obvious natural key exists (e.g.
/// [SavingsGoalContributions]), because those rows are independent
/// financial events/entities that other tables may need to reference by
/// a stable id, soft-delete, etc. A reference-rate cache row has no such
/// independent identity — it simply IS "the current cached rate for
/// `(baseCurrency, quoteCurrency)`", nothing else in the schema
/// references it by id, and CP9.3 requires "at most one row per ordered
/// pair" with deterministic replace-on-conflict (cache) behavior, not the
/// reject-a-second-write behavior [TransactionExchangeRates] enforces at
/// the repository layer for a completely different reason (immutability).
/// Declaring `(baseCurrency, quoteCurrency)` as the actual composite
/// primary key gets that invariant enforced by SQLite itself and lets
/// `DriftReferenceFxRateCache.put` use Drift's `insertOnConflictUpdate`
/// (`INSERT ... ON CONFLICT(...) DO UPDATE`) directly, with no separate
/// UNIQUE index or manual check-then-insert-or-update dance.
///
/// `(USD, JPY)` and `(JPY, USD)` are different primary keys — this table
/// never inverts, merges, or otherwise conflates a pair with its reverse
/// (see [FxRate]'s own directional-rate contract).
class ReferenceExchangeRates extends Table {
  /// ISO 4217 code, canonical/upper-case — see
  /// `CurrencyRegistry`/`FxRate.baseCurrencyCode`. Half of the composite
  /// primary key.
  TextColumn get baseCurrency => text()();

  /// ISO 4217 code, canonical/upper-case. Half of the composite primary
  /// key — `(baseCurrency, quoteCurrency)` and `(quoteCurrency,
  /// baseCurrency)` are always distinct rows, never merged or inverted.
  TextColumn get quoteCurrency => text()();

  /// Full-precision decimal string — e.g. "150.25", "0.006666666667".
  /// Deliberately TEXT, never REAL — identical reasoning to
  /// [TransactionExchangeRates.rate] (ADR-018): an exchange rate must
  /// never be rounded merely by virtue of how it's stored.
  TextColumn get rate => text()();

  /// Free-text provenance. Matches [TransactionExchangeRates.provider]'s
  /// column-naming precedent within this schema file (the corresponding
  /// domain field is `ReferenceFxRate.source` — same
  /// column-name-vs-domain-field-name mapping
  /// `TransactionExchangeRateRepository` already uses for the sibling
  /// table).
  TextColumn get provider => text()();

  /// When the provider says this rate was actually observed/quoted. A
  /// genuine instant — see `ReferenceFxRate.observedAt`.
  DateTimeColumn get observedAt => dateTime()();

  /// When this rate was fetched/cached. A genuine instant — see
  /// `ReferenceFxRate.fetchedAt`. `ReferenceFxRateService`'s freshness
  /// comparison is measured against this column, never [observedAt].
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{baseCurrency, quoteCurrency};
}


/// Checkpoint 12.2 (Cloud Identity / Auth Foundation): the smallest local
/// representation of "this local profile is associated with one
/// authenticated cloud user" -- see `docs/21_CLOUD_SYNC_ARCHITECTURE.md`
/// §3 for the full V1 identity contract this table implements.
///
/// # This is device-local bookkeeping, not synced user data
///
/// Unlike every financial table in this file, `CloudAccountLinks` has no
/// `deletedAt`, `syncVersion`, or `syncStatus` column, and it never will
/// by accident: this row does not represent a user's financial fact that
/// a future sync engine uploads/downloads -- it represents which cloud
/// account THIS INSTALL currently considers itself linked to, which is
/// inherently per-device metadata (CP12.1 §1.14/§9's "what must NOT
/// sync" boundary). If a later checkpoint ever needs to sync
/// account-linkage across a user's own devices, that is a deliberate,
/// separately-designed feature -- not something this table drifts into
/// by reusing the sync-metadata column shape other tables have.
///
/// # Primary key -- `profileId`, a natural key, same departure as
/// [ReferenceExchangeRates]
///
/// V1 supports "zero or one active cloud account on a device" (see the
/// architecture doc's §3), and Beta 0/1 already guarantee at most one
/// local [Profiles] row per install (see [Profiles]' own doc / Beta 0
/// scope). Composing those two constraints, at most one
/// `CloudAccountLinks` row can ever legitimately exist per install, and
/// it is always "the link for THIS profile" -- there is no independent
/// identity for a link row the way [ReferenceExchangeRates]' doc
/// explains a cache row has none either. A surrogate `id` here would
/// only invite a second row per profile to accidentally exist with no
/// application-level rule preventing it; the natural key prevents that
/// by construction, the same way [ReferenceExchangeRates]'s composite
/// key does.
///
/// # What is deliberately NOT stored here
///
/// No access token, refresh token, password, or any other secret --
/// see `lib/core/cloud_identity/secure_token_store.dart` for where a
/// real token would eventually live (never Drift, never this table,
/// never any other ordinary SQL table in this schema). No email,
/// display name, or other cloud-profile data -- V1 has no real backend
/// to source that from yet (see `UnavailableCloudAuthProvider`'s doc),
/// and this table only needs to answer "which cloud_user_id, if any,
/// is this install linked to, and in what state" -- not to duplicate
/// anything a real backend would remain the source of truth for later.
/// No `deviceId`/install id column either -- CP12.2's instruction is
/// explicit that a device/install id, if the approved architecture ever
/// needs one, remains device-local and must never be treated as user
/// identity; this table doesn't need one to satisfy "zero or one active
/// cloud account on a device" since it's already scoped to the single
/// local [Profiles] row via [profileId].
class CloudAccountLinks extends Table {
  /// The local profile this link belongs to. A natural-key reference
  /// into [Profiles] -- see the class doc for why this (not a surrogate
  /// `id`) is the primary key.
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The stable, server-assigned cloud user identifier -- CP12.2's
  /// instruction is explicit that this is "supplied by the authenticated
  /// server/provider" and must never be manufactured locally (see
  /// `CloudAuthSession.cloudUserId`). Deliberately kept even after
  /// sign-out (see [status] below) -- remembering which cloud account
  /// this install was last linked to is exactly what lets
  /// `CloudAccountLinkRepository.recordSignIn` detect and refuse an
  /// attempt to sign into a DIFFERENT cloud account on a device that
  /// still has this profile's local financial data (the
  /// `DifferentCloudAccountLinkedException` contract).
  TextColumn get cloudUserId => text()();

  /// One of [CloudAccountLinkStatus.storageValue] --
  /// `'active'` | `'signedOut'` | `'sessionExpired'`. Deliberately a
  /// plain `TextColumn`, not a foreign key or generated column -- same
  /// pattern `profiles.theme_preference` already uses in this schema for
  /// an enum-shaped value with a safe, never-throws decode on read (see
  /// `CloudAccountLinkStatus.fromStorageValue`).
  TextColumn get status => text()();

  /// When this profile was FIRST linked to [cloudUserId]. Deliberately
  /// never advanced by a later sign-out/sign-back-in cycle into the
  /// SAME account -- only a genuine different-account link (which is
  /// refused, per [cloudUserId]'s doc) or the first-ever link sets this.
  DateTimeColumn get linkedAt => dateTime()();

  /// Advances on every state transition (`recordSignIn`, `recordSignOut`,
  /// `recordSessionExpired`) -- same convention as every other table's
  /// `updated_at` in this schema.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{profileId};
}
