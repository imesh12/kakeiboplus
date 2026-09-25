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


/// Checkpoint B (schema v9): a named financial-services provider (e.g.
/// "MUFG Bank", "Commercial Bank of Ceylon", "Rakuten") that a
/// `FinancialAccount` (physically still the `accounts` table -- see
/// this file's `Accounts` class doc) may optionally belong to. Never
/// balance-holding -- see
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §12.1 and
/// ADR-035.
///
/// Optional by design: cash and other institution-less products leave
/// `Accounts.institutionId` null -- this table is never required to
/// have a row for an account to exist. Checkpoint B creates this table
/// but deliberately creates zero rows in it and builds no
/// institution-management UI -- see the Checkpoint B brief. A later
/// checkpoint (docs/20 §13.4, checkpoint G/H) is what actually lets a
/// user create/assign institutions.
@DataClassName('FinancialInstitutionRow')
class FinancialInstitutions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();

  /// ISO 3166-1 alpha-2, e.g. "JP", "LK". Optional -- see docs/20 §12.1.
  TextColumn get countryCode => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete -- same convention as `Accounts`/`Transactions`. An
  /// institution being archived must never invalidate a
  /// `FinancialAccount` that references it via `Accounts.institutionId`
  /// -- see the Checkpoint B brief's "foreign key / relationship
  /// discipline" section. No FK cascade is configured (this schema
  /// never configures one -- see e.g. `Transactions.accountId`); a
  /// referencing account simply keeps its `institutionId` pointing at a
  /// soft-deleted row, whose `name` the presentation layer may still
  /// read (a future checkpoint's concern, not this one's).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Sync foundation, added from creation -- consistent with every
  /// table from schema v2 onward (see `Accounts.syncVersion`'s own doc
  /// for why `accounts` itself was the one exception, now fixed by this
  /// same checkpoint).
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

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
  ///
  /// Checkpoint B (schema v9) freezes this as presentation-only /
  /// backward-compatibility metadata going forward -- [balanceClass]
  /// and [subtype] below are now the authoritative fields for
  /// accounting semantics (docs/20 §12.2/§13.1, ADR-035). This column is
  /// deliberately NOT removed or renamed in this checkpoint: existing
  /// production code (`accounts_screen.dart`, `account_detail_screen
  /// .dart`, `edit_account_screen.dart`) still reads and
  /// `AccountRepository.updateAccount` still writes it, and a broad
  /// presentation migration is out of scope for this checkpoint. A
  /// migrated legacy 'card' row, for example, keeps `type == 'card'`
  /// forever unless a user edits it through the existing Edit Account
  /// screen -- its `subtype` (`legacyCardNeedsReview`) is a completely
  /// separate column, unaffected by that edit either way.
  TextColumn get type => text()();
  TextColumn get currencyCode => text().references(Currencies, #code)();

  /// Money, stored as integer minor units — see ADR-017. Never a REAL
  /// column.
  IntColumn get openingBalanceMinorUnits => integer().withDefault(const Constant(0))();

  /// Account Lifecycle Checkpoint: together with [deletedAt] below, this
  /// is what "closed" (a.k.a. "deactivated"/"reopened") means for an
  /// account -- `AccountRepository.softDelete`/`reactivate` toggle both
  /// together, and `AccountRepository.watchActiveForProfile` filters on
  /// both. Unlike every OTHER `deletedAt` in this schema (`Transactions`/
  /// `Budgets`/`RecurringRules`/`SavingsGoals`, each a permanent, no-undo
  /// -UI delete from the user's perspective), an account's is
  /// deliberately reversible -- see [deletedAt]'s own doc. Present since
  /// before this checkpoint (schema v2) but never wired to any
  /// production UI action until now.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Account Lifecycle Checkpoint: set (together with [isActive] above)
  /// when a user closes an account via `AccountRepository.softDelete`,
  /// cleared by `AccountRepository.reactivate`. Deliberately reversible
  /// -- see [isActive]'s own doc for why this is NOT the same convention
  /// as every other `deletedAt` in this schema. A closed account's row
  /// remains fully resolvable (`AccountRepository.watchById`/
  /// `watchAllForProfile`) for its transaction history and for
  /// reactivation; only `watchActiveForProfile` (new-transaction
  /// account-selector population) and the presentation layer's
  /// "editable" gating treat this as unavailable.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Checkpoint B (schema v9): the frozen asset/liability classification
  /// -- `lib/core/finance/balance_class.dart`'s `BalanceClass`, stored
  /// as `storageValue`. Authoritative for accounting semantics (see
  /// [type]'s own doc above). Immutable once this account has any
  /// financial history -- `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE
  /// .md` §12.2 -- enforced by `AccountRepository`'s update-method shape
  /// never accepting this field at all, not by a runtime check. Every
  /// row this checkpoint's migration backfills, and every row the
  /// current (not yet redesigned) Add Account UX creates, gets `'asset'`
  /// -- this checkpoint never writes `'liability'` anywhere; see
  /// `docs/20` §13.1 and the Checkpoint B report.
  TextColumn get balanceClass =>
      text().withDefault(const Constant('asset'))();

  /// Checkpoint B (schema v9): the frozen product subtype --
  /// `lib/core/finance/financial_account_subtype.dart`'s
  /// `FinancialAccountSubtype`, stored as `storageValue`. Authoritative
  /// for accounting semantics alongside [balanceClass]. Immutable by
  /// default once this account has history -- same enforcement
  /// discipline as [balanceClass]. Defaults to `'legacyUnknownNeedsReview'`
  /// -- the same conservative fallback this checkpoint's migration uses
  /// for any legacy [type] string it does not recognize (docs/20
  /// §13.1) -- so a row inserted without an explicit value (e.g. a test
  /// fixture that bypasses `AccountRepository.createAccount`) is always
  /// flagged for review rather than silently misclassified.
  TextColumn get subtype =>
      text().withDefault(const Constant('legacyUnknownNeedsReview'))();

  /// Checkpoint B (schema v9): the optional `FinancialInstitutions` this
  /// account belongs to -- docs/20 §12.1. Null for cash and any other
  /// institution-less product; this checkpoint never fabricates an
  /// institution row to populate this during migration (docs/20 §13.1
  /// / the Checkpoint B brief) -- every migrated and newly-created
  /// account gets `institutionId == null`.
  TextColumn get institutionId =>
      text().nullable().references(FinancialInstitutions, #id)();

  /// Checkpoint B (schema v9) also folds in the already-committed
  /// `accounts.syncVersion`/`accounts.syncStatus` gap from
  /// `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §11 / ADR-032 into this same
  /// version bump, per `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE
  /// .md` §13.1's explicit instruction not to migrate `accounts` twice.
  /// `accounts` was the one table from schema v2 onward missing this
  /// pair -- see every other table in this file for the identical
  /// convention. Forward-compatible per ADR-020's precedent -- inert
  /// until Stage 6 (cloud/sync); this checkpoint always writes 0 /
  /// "localOnly" and never reads these outside of that constant.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Checkpoint D: HOW a `FinancialAccount` (physically the `accounts`
/// table) was used to pay or receive money -- e.g. "the Visa debit card
/// on my checking account", "my Amex credit card". A `PaymentInstrument`
/// is explicitly NOT a `FinancialAccount` -- see this file's `Accounts`
/// doc and `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md`. It:
///
/// - links to exactly ONE `accounts` row (never zero, never many -- no
///   join table backs this for V1; the future shared-credit-facility
///   case is one liability `FinancialAccount` referenced by *multiple*
///   `PaymentInstruments` rows, never the reverse);
/// - optionally belongs to a `FinancialInstitutions` row;
/// - carries ZERO independent accounting balance and contributes ZERO
///   independently to any asset/liability/net-worth calculation --
///   `FinanceEngine` never reads this table at all (see
///   `lib/core/finance/finance_engine.dart`).
///
/// Physical column naming note: this column is named `accountId`
/// (matching `Transactions.accountId`'s own naming), even though
/// conceptually it points at the unified `FinancialAccount` model
/// (docs/20 §12) rather than a literal legacy "account" -- `accountId`
/// is more consistent with this schema's existing naming than a
/// `financialAccountId` column would be, and `Accounts` itself is not
/// renamed by this or any checkpoint.
@DataClassName('PaymentInstrumentRow')
class PaymentInstruments extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The single `FinancialAccount` (physically `accounts`) this
  /// instrument is used to pay from / receive into. Immutable after
  /// creation -- see `PaymentInstrumentRepository.updateMetadata`'s own
  /// doc for why relinking is deliberately not exposed as a generic
  /// update in this checkpoint.
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Optional -- e.g. "MUFG Bank" for a debit card, null for a payment
  /// service the user hasn't associated with an institution. Never
  /// required -- see `FinancialInstitutions`' own doc above.
  TextColumn get institutionId =>
      text().nullable().references(FinancialInstitutions, #id)();

  /// One of `PaymentInstrumentType.storageValue` --
  /// `lib/core/finance/payment_instrument_type.dart`. Metadata only --
  /// NOT itself an accounting classification (see that enum's own doc).
  /// Immutable after creation by default, matching [accountId]/
  /// [profileId] -- see `PaymentInstrumentRepository`'s update-method
  /// doc.
  TextColumn get instrumentType => text()();

  /// One of `CardNetwork.storageValue`, or null --
  /// `lib/core/finance/card_network.dart`. Optional for every
  /// instrument type; never required.
  TextColumn get network => text().nullable()();

  /// User-chosen label, e.g. "Everyday debit card". Freely editable.
  TextColumn get nickname => text()();

  /// Exactly 4 decimal digits when present, or null -- validated by
  /// `PaymentInstrumentRepository`, never a full card number/PAN. See
  /// the Checkpoint D brief's "sensitive data boundary" section: this
  /// table never stores a full card number, CVV/CVC, PIN, magnetic
  /// stripe data, or any authentication credential.
  TextColumn get last4 => text().nullable()();

  /// 1-12 when present. [expiryMonth] and [expiryYear] are validated as
  /// both-null-or-both-present by `PaymentInstrumentRepository` -- see
  /// that repository's doc for why this "both or neither" rule was
  /// chosen over allowing either half alone.
  IntColumn get expiryMonth => integer().nullable()();
  IntColumn get expiryYear => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete/archive -- same convention as `Accounts`/
  /// `Transactions`/`FinancialInstitutions`. An instrument referenced by
  /// historical `Transactions.paymentInstrumentId` rows must never
  /// require hard deletion, and archiving one must never invalidate
  /// those historical rows -- see the Checkpoint D brief's "lifecycle /
  /// history" section. `PaymentInstrumentRepository`'s active-selection
  /// queries exclude a soft-deleted row; its historical-resolution
  /// lookup does not.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Sync foundation, added from creation -- consistent with every
  /// table from schema v2 onward (see `Accounts.syncVersion`'s own doc
  /// for the one historical exception, already fixed by Checkpoint B).
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Checkpoint E (schema v11): one-to-one metadata for a credit-facility
/// liability `FinancialAccount` -- present if and only if that account
/// has `balanceClass: liability` and `subtype: creditCard` (docs/20
/// §12.1, §13.4 checkpoint E). Never balance-holding itself --
/// `creditLimitMinorUnits` never participates in any
/// `FinanceEngine`/ledger-balance computation; "available credit" is
/// always DERIVED (`creditLimit - amountOwed`, via `Money`'s own `-`
/// operator) and never stored -- see
/// `CreditFacilityRepository.availableCredit`.
///
/// Enforced one-to-one with its `FinancialAccount` via [accountId]'s
/// `unique()` constraint below, backed by `CreditFacilityRepository`'s
/// own pre-check for a clear domain exception rather than a raw SQLite
/// constraint violation surfacing to a caller.
@DataClassName('CreditFacilityDetailsRow')
class CreditFacilityDetails extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The single liability `FinancialAccount` (physically `accounts`)
  /// this facility describes -- see this table's own doc and
  /// `PaymentInstruments.accountId`'s identical physical-naming
  /// rationale (this column names the same conceptual target the same
  /// way, for the same reason: consistency with this schema's existing
  /// naming, not a literal legacy "account"). `unique()` enforces the
  /// one-facility-per-account invariant at the database level;
  /// `CreditFacilityRepository.createFacility` checks for an existing
  /// row first so a violation surfaces as
  /// `CreditFacilityValidationException`, not a raw SQLite error.
  TextColumn get accountId => text().unique().references(Accounts, #id)();

  /// Money, stored as integer minor units in the linked account's OWN
  /// currency -- this table deliberately has no `currencyCode` column
  /// of its own (docs/20 §12.3's "Currency is inherited from the
  /// FinancialAccount" rule) -- see `CreditFacilityRepository
  /// .createFacility`'s doc for how a mismatched `Money` currency is
  /// rejected at creation. Zero is a valid limit (e.g. a facility
  /// pending its first credit-limit assignment); only a NEGATIVE limit
  /// is rejected -- see that method's own doc for the full rationale.
  /// Never decremented/incremented directly by a purchase or payment --
  /// see this table's own doc on "available credit."
  IntColumn get creditLimitMinorUnits => integer()();

  /// Day-of-month (1-31) the statement closes, if known -- docs/20
  /// §12.1/§13.5 open question 2. Optional and independent of [dueDay]
  /// (unlike `PaymentInstruments.expiryMonth`/`expiryYear`, there is no
  /// "both or neither" rule between these two -- a user may know one
  /// without the other). No billing-cycle computation reads this in V1
  /// -- purely informational metadata (docs/20 §13.4 checkpoint E: "do
  /// not invent large billing-cycle functionality that belongs later").
  IntColumn get statementClosingDay => integer().nullable()();

  /// Day-of-month (1-31) payment is due, if known -- same optionality
  /// and "no billing-cycle computation" rule as [statementClosingDay].
  IntColumn get dueDay => integer().nullable()();

  /// The asset `FinancialAccount` normally used to pay this facility's
  /// statement, if the user has one in mind -- docs/20 §12.1.
  /// **Informational only, never enforced**: `TransactionRepository
  /// .recordTransfer` does not read this column, does not require a
  /// payment's source account to match it, and no validation anywhere
  /// rejects a payment from a different account. Nullable; validated
  /// only for existence/profile-ownership at creation (see
  /// `CreditFacilityRepository.createFacility`'s doc), never for
  /// `balanceClass`/`subtype` -- the frozen model does not restrict
  /// which account a user intends to pay from.
  TextColumn get linkedPaymentAccountId =>
      text().nullable().references(Accounts, #id)();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete -- same convention as every other table in this schema
  /// from v2 onward. Checkpoint E does not build a lifecycle/UI path
  /// that ever sets this (no facility-deletion flow exists in V1); the
  /// column exists for schema-wide consistency and so a later
  /// checkpoint never needs a fresh migration merely to add it.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Checkpoint F: one-to-one metadata for a deposit ASSET
/// `FinancialAccount` -- docs/20 §12.1/§12.7/§12.8/§12.9. Present if and
/// only if the linked `FinancialAccount` has `balanceClass: asset` and
/// `subtype: deposit` (see `DepositRepository.createDetails`'s creation
/// validation for the full rationale, mirroring `CreditFacilityDetails`'s
/// identical account-eligibility pattern). Carries **zero ledger
/// balance of its own** -- there is no principal/balance column here at
/// all; the deposit's principal is simply its linked `FinancialAccount`'s
/// own balance (`FinanceEngine.accountBalance`, unchanged), exactly the
/// same "PaymentInstrument/CreditFacilityDetails never duplicate the
/// ledger" discipline every prior detail table in this schema already
/// established.
@DataClassName('DepositDetailsRow')
class DepositDetails extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The single asset `FinancialAccount` (physically `accounts`) this
  /// deposit's metadata describes. `unique()` enforces the
  /// one-deposit-per-account invariant at the database level;
  /// `DepositRepository.createDetails` checks for an existing row first
  /// so a violation surfaces as `DepositValidationException`, not a raw
  /// SQLite error -- the same pattern `CreditFacilityDetails.accountId`
  /// already established.
  TextColumn get accountId => text().unique().references(Accounts, #id)();

  /// `fixed` / `shortTerm` / `recurring` / `other` -- docs/20 §12.1's
  /// exact frozen values (see `DepositType`). Gates whether
  /// [installmentAmountMinorUnits]/[installmentFrequency] may be set
  /// (only for `recurring`) -- see `DepositRepository.createDetails`.
  TextColumn get depositType => text()();

  /// A whole number, always `>= 1` -- paired with [termUnit] to define
  /// the deposit's declared term. Docs/20 §12.1.
  IntColumn get termNumber => integer()();

  /// `days` / `months` / `years` -- docs/20 §12.1 (see [DepositTermUnit]).
  /// Selects which calendar-arithmetic path `DepositRepository
  /// .createDetails` uses to compute [maturityDate] from [startDate] and
  /// [termNumber] -- plain calendar-day addition for `days`;
  /// `calendar_month_math.dart`'s anchor-based, leap-year-aware
  /// arithmetic for `months`/`years` (docs/20 §12.7 -- reusing the exact
  /// routine `RecurringSchedule` already uses, not a second one).
  TextColumn get termUnit => text()();

  /// Calendar-only UTC-midnight date -- the deposit's first day.
  DateTimeColumn get startDate => dateTime()();

  /// Calendar-only UTC-midnight date. **Computed once, at creation, from
  /// [startDate]/[termNumber]/[termUnit], and stored** -- docs/20 §12.7:
  /// "so the figure never drifts if calculation rules change later."
  /// This is the ONE derived value this table deliberately persists
  /// (unlike `DepositEstimate`'s estimated-interest/maturity-value
  /// figures, which are calendar-date-independent money amounts that
  /// must NEVER be persisted, docs/20 §12.8) -- a calendar date frozen
  /// at creation time is architecturally different from a money estimate
  /// that depends on a rate/day-count convention that could theoretically
  /// change later.
  DateTimeColumn get maturityDate => dateTime()();

  /// The annual interest rate in basis points (e.g. `550` = 5.50%) --
  /// docs/20 §12.8's frozen representation, converted to an exact
  /// fraction (`/10000`) only at calculation time in `DepositCalculator`
  /// -- never a stored `double` rate. Non-negative; zero is a valid rate
  /// (docs/20 test item 21 -- e.g. a promotional zero-interest
  /// introductory deposit).
  IntColumn get interestRateBasisPoints => integer()();

  /// `simple` / `compound` -- docs/20 §12.8 (see [DepositInterestMethod]).
  /// Selects which `DepositCalculator` formula applies, and gates
  /// [compoundingFrequency] (required for `compound`, must be absent for
  /// `simple` -- see `DepositRepository.createDetails`).
  TextColumn get interestMethod => text()();

  /// `monthly` / `quarterly` / `semiannual` / `annual` / `atMaturity` --
  /// docs/20 §12.8 (see [DepositCompoundingFrequency]). Meaningful ONLY
  /// when [interestMethod] is `compound` -- `null` whenever
  /// [interestMethod] is `simple` (`DepositRepository.createDetails`
  /// rejects a non-null value for `simple`, matching this table's own
  /// "meaningful only for compound" doc on the parent architecture
  /// section).
  TextColumn get compoundingFrequency => text().nullable()();

  /// Whether this deposit renews automatically at maturity -- docs/20
  /// §12.1. Defaults to `false`. **No automatic-renewal behavior is
  /// implemented in V1** (this checkpoint's own explicit scope
  /// exclusion: "Do NOT implement automatic maturity posting") -- purely
  /// a stored declaration of intent for a future checkpoint's UI/renewal
  /// engine to read.
  BoolColumn get autoRenew => boolean().withDefault(const Constant(false))();

  /// Free-form, informational description of what happens on renewal
  /// (e.g. "principal only" / "principal + interest") -- docs/20 §12.1
  /// names this field but does not freeze a fixed set of values for it,
  /// unlike every other enum-shaped column on this table. Deliberately
  /// left as plain text rather than an invented enum -- inventing a
  /// closed set of renewal modes here would be exactly the "do not
  /// invent bank-specific product categories" / "do not guess bank
  /// behavior" this checkpoint explicitly warns against. Nullable; never
  /// read or interpreted by any code in this checkpoint.
  TextColumn get renewalMode => text().nullable()();

  /// The asset `FinancialAccount` interest is paid into, if different
  /// from the deposit account itself -- docs/20 §12.1. **Unlike
  /// `CreditFacilityDetails.linkedPaymentAccountId`, this IS validated
  /// for currency** (`DepositRepository.createDetails` requires it to
  /// share [accountId]'s currency) -- interest is actually postable here
  /// in V1 via an ordinary `TransactionRepository.recordIncome` call with
  /// no FX conversion step, so a currency mismatch would silently
  /// misstate which currency the posted interest is denominated in; a
  /// purely-informational field like `linkedPaymentAccountId` never
  /// reaches that code path at all. Self-referencing (equal to
  /// [accountId]) is explicitly ALLOWED -- interest reinvested back into
  /// the same deposit is a legitimate real-world pattern, not a circular
  /// relationship (see `DepositRepository.createDetails`'s doc for the
  /// full reasoning). Nullable; validated only for existence/profile-
  /// ownership/currency at creation, never `balanceClass`/`subtype`.
  TextColumn get interestDestinationAccountId =>
      text().nullable().references(Accounts, #id)();

  /// Only meaningful for `depositType: recurring` -- docs/20 §12.9.
  /// `DepositRepository.createDetails` rejects a non-null value for any
  /// other [depositType]. Purely descriptive in V1 -- see
  /// `DepositInstallmentFrequency`'s own doc for why V1 stores but never
  /// schedules against this.
  IntColumn get installmentAmountMinorUnits => integer().nullable()();

  /// Only meaningful for `depositType: recurring` -- same gating as
  /// [installmentAmountMinorUnits]. See [DepositInstallmentFrequency].
  TextColumn get installmentFrequency => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete -- same convention as every other table in this schema
  /// from v2 onward. Checkpoint F does not build a lifecycle/UI path
  /// that ever sets this (no deposit-deletion flow exists in V1); the
  /// column exists for schema-wide consistency and so a later checkpoint
  /// never needs a fresh migration merely to add it.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('localOnly'))();

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

  /// Checkpoint D (schema v10): optional attribution to the specific
  /// `PaymentInstrument` used -- e.g. "paid with my Amex", distinct from
  /// [accountId] (WHICH account the money moved through). Purely
  /// metadata: `FinanceEngine`/`LedgerTransaction` never read this
  /// column and it has ZERO effect on any balance, income/expense
  /// total, or transfer calculation -- see
  /// `lib/core/finance/finance_engine.dart` and the Checkpoint D
  /// brief's "validation boundary" section. Null for every transaction
  /// recorded before this column existed (this migration never
  /// fabricates attribution for historical rows) and for any
  /// transaction the user simply doesn't attribute to a specific
  /// instrument -- always optional, never required.
  ///
  /// `TransactionRepository` enforces the V1 source-attribution rule
  /// when this is supplied: the referenced instrument's own `accountId`
  /// must equal this row's [accountId] (for a transfer, the SOURCE
  /// account) -- see that repository's own doc and
  /// `InvalidPaymentInstrumentAttributionException`.
  TextColumn get paymentInstrumentId =>
      text().nullable().references(PaymentInstruments, #id)();

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
