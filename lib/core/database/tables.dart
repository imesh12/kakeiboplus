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
