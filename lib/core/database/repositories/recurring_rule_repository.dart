import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/recurring/domain/recurrence_frequency.dart';
import '../../../features/recurring/domain/recurring_rule_kind.dart';
import '../../../features/recurring/domain/recurring_schedule.dart';
import '../../currency/currency_registry.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'account_repository.dart';

/// Thrown when an attempt is made to persist a recurring rule whose
/// amount is not strictly positive. Mirrors
/// `SavingsGoalRepository`'s/`BudgetRepository`'s equivalent exceptions
/// -- see `docs/14_DECISION_LOG.md` ADR-023.
class InvalidRecurringRuleAmountException implements Exception {
  InvalidRecurringRuleAmountException(this.amount);
  final Money amount;
  @override
  String toString() =>
      'InvalidRecurringRuleAmountException: amount must be strictly positive, got $amount';
}

/// Thrown when an attempt is made to persist a recurring rule whose name
/// is empty or contains only whitespace.
class InvalidRecurringRuleNameException implements Exception {
  InvalidRecurringRuleNameException(this.name);
  final String name;
  @override
  String toString() =>
      'InvalidRecurringRuleNameException: name must not be empty or whitespace-only, got "$name"';
}

/// Thrown when [RecurringRuleRepository.requireActiveRule] (or an
/// operation that depends on it, such as posting an occurrence) is asked
/// for a rule id that either does not exist or has been soft-deleted.
class RecurringRuleNotFoundException implements Exception {
  RecurringRuleNotFoundException(this.id);
  final String id;
  @override
  String toString() => 'RecurringRuleNotFoundException: no active recurring rule with id "$id"';
}

/// The repository behind Beta 1 Task 4A's recurring rules: creating,
/// updating, and soft-deleting schedule/template rows, and reading them
/// back. **A rule is a schedule/template only** -- creating or updating
/// one never writes to `Transactions`, never affects an account balance,
/// income/expense total, budget, goal, or dashboard figure. Only
/// [RecurringOccurrenceRepository.postOccurrence] does that, and only
/// when explicitly called -- see `docs/14_DECISION_LOG.md` ADR-023.
///
/// **Editing affects future schedule calculations only.** Updating
/// [frequency]/[interval]/`startDate`/`endDate` changes what
/// `RecurringSchedule.occurrencesInRange` (etc.) compute from this row
/// from that point on, but never touches an already-written
/// `RecurringOccurrences` row or `Transactions` row -- those are
/// separate, immutable-once-created records keyed by their own
/// `scheduledDate`/id, never re-derived from the rule after the fact.
///
/// **Validation, same application-layer precedent as
/// `TransactionRepository.recordTransfer` (ADR-019) and
/// `SavingsGoalRepository`/`BudgetRepository` (ADR-021/ADR-022):**
///  - `amount` must be strictly positive, in a [CurrencyRegistry]-known
///    currency.
///  - `interval` must be `>= 1`.
///  - expense/income: exactly one account; the rule's currency must
///    match that account's currency; no destination account.
///  - transfer: a source AND a destination account, source != dest, both
///    accounts share a currency, and the rule's currency matches both --
///    a cross-currency recurring transfer is rejected, never coerced.
class RecurringRuleRepository {
  RecurringRuleRepository(this._db, this._accountRepository);

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  static const Uuid _uuid = Uuid();

  /// See `SavingsGoalRepository._withUtcDateTimes`'s doc comment: Drift's
  /// default (non-text) `DateTime` storage round-trips the correct
  /// instant but reads it back tagged local, not UTC. Every `DateTime`
  /// this table stores is written UTC-tagged, so this re-tags each one
  /// back to UTC on the way out -- `.toUtc()` never moves the underlying
  /// instant, so this cannot alter any already-persisted data or shift
  /// the calendar date `normalizeRecurringDate` selected.
  static RecurringRuleRow _withUtcDateTimes(RecurringRuleRow row) {
    return row.copyWith(
      startDate: row.startDate.toUtc(),
      endDate: Value<DateTime?>(row.endDate?.toUtc()),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      deletedAt: Value<DateTime?>(row.deletedAt?.toUtc()),
    );
  }

  String _validateName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw InvalidRecurringRuleNameException(name);
    }
    return trimmed;
  }

  void _validateAmount(Money amount) {
    if (!amount.isPositive) {
      throw InvalidRecurringRuleAmountException(amount);
    }
    // Throws ArgumentError if currencyCode isn't a known currency --
    // surfaces an unsupported currency immediately, at write time.
    CurrencyRegistry.require(amount.currencyCode);
  }

  void _validateInterval(int interval) {
    if (interval < 1) {
      throw ArgumentError.value(interval, 'interval', 'interval must be >= 1.');
    }
  }

  void _validateDateRange(DateTime startDate, DateTime? endDate) {
    if (endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError.value(endDate, 'endDate', 'endDate must not be before startDate.');
    }
  }

  /// Validates the account(s)/currency shape for [kind] -- see the class
  /// doc comment. Returns nothing; throws on any violation.
  Future<void> _validateAccounts({
    required RecurringRuleKind kind,
    required String accountId,
    required String? destinationAccountId,
    required String currencyCode,
  }) async {
    final AccountRow account = await _accountRepository.requireById(accountId);

    if (kind == RecurringRuleKind.transfer) {
      if (destinationAccountId == null) {
        throw ArgumentError.value(
          destinationAccountId,
          'destinationAccountId',
          'A transfer rule requires a destination account.',
        );
      }
      if (destinationAccountId == accountId) {
        throw ArgumentError.value(
          destinationAccountId,
          'destinationAccountId',
          'Source and destination accounts must be different.',
        );
      }
      final AccountRow destination = await _accountRepository.requireById(destinationAccountId);
      if (account.currencyCode != destination.currencyCode) {
        throw CurrencyMismatchException(account.currencyCode, destination.currencyCode);
      }
      if (currencyCode != account.currencyCode) {
        throw CurrencyMismatchException(account.currencyCode, currencyCode);
      }
    } else {
      if (destinationAccountId != null) {
        throw ArgumentError.value(
          destinationAccountId,
          'destinationAccountId',
          '${kind.name} rules must not set a destination account.',
        );
      }
      if (currencyCode != account.currencyCode) {
        throw CurrencyMismatchException(account.currencyCode, currencyCode);
      }
    }
  }

  /// Creates a new recurring rule. See the class doc comment for every
  /// validation rule this enforces before any row is written.
  Future<String> createRule({
    required String profileId,
    required RecurringRuleKind kind,
    required String name,
    required Money amount,
    required String accountId,
    String? destinationAccountId,
    String? categoryId,
    String? serviceIdentityKey,
    String? note,
    required RecurrenceFrequency frequency,
    required int interval,
    required DateTime startDate,
    DateTime? endDate,
    bool notificationsEnabled = false,
  }) async {
    final String trimmedName = _validateName(name);
    _validateAmount(amount);
    _validateInterval(interval);
    final DateTime normalizedStart = normalizeRecurringDate(startDate);
    final DateTime? normalizedEnd = endDate == null ? null : normalizeRecurringDate(endDate);
    _validateDateRange(normalizedStart, normalizedEnd);
    await _validateAccounts(
      kind: kind,
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      currencyCode: amount.currencyCode,
    );
    if (kind == RecurringRuleKind.transfer) {
      // Transfers are never categorized, and never carry a service
      // identity either -- same convention as
      // `TransactionRepository.recordTransfer`.
      categoryId = null;
      serviceIdentityKey = null;
    }

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            id: id,
            profileId: profileId,
            kind: kind.name,
            name: trimmedName,
            amountMinorUnits: amount.minorUnits,
            currencyCode: amount.currencyCode,
            accountId: accountId,
            destinationAccountId: Value<String?>(destinationAccountId),
            categoryId: Value<String?>(categoryId),
            serviceIdentityKey: Value<String?>(serviceIdentityKey),
            note: Value<String?>(note),
            frequency: frequency.name,
            interval: Value<int>(interval),
            startDate: normalizedStart,
            endDate: Value<DateTime?>(normalizedEnd),
            notificationsEnabled: Value<bool>(notificationsEnabled),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Updates an existing, active recurring rule. Every parameter besides
  /// [id] is "leave unchanged" when omitted (plain `null`), except
  /// [endDate], which uses drift's [Value] sentinel so "explicitly
  /// clear" is distinguishable from "leave unchanged" -- same convention
  /// [SavingsGoalRepository.updateGoal] already established for
  /// `targetDate`. [kind]/[accountId]/[destinationAccountId]/
  /// [currency] together are re-validated as a whole whenever any of
  /// them changes, using the existing row's values for whichever ones
  /// weren't passed.
  ///
  /// [kind] (expense/income/transfer) is permanently fixed at creation
  /// and cannot be changed here -- the account/currency shape those
  /// three kinds require is different enough (one account vs. two, a
  /// nullable destination) that "editing" a rule's kind is really
  /// "replace this rule with a different one", which
  /// `RecurringRuleRepository` doesn't attempt to support implicitly.
  ///
  /// Never touches any `RecurringOccurrences` or `Transactions` row --
  /// see the class doc comment.
  Future<void> updateRule({
    required String id,
    String? name,
    Money? amount,
    String? accountId,
    Value<String?> destinationAccountId = const Value<String?>.absent(),
    Value<String?> categoryId = const Value<String?>.absent(),
    Value<String?> serviceIdentityKey = const Value<String?>.absent(),
    Value<String?> note = const Value<String?>.absent(),
    RecurrenceFrequency? frequency,
    int? interval,
    DateTime? startDate,
    Value<DateTime?> endDate = const Value<DateTime?>.absent(),
    Value<bool> notificationsEnabled = const Value<bool>.absent(),
  }) async {
    final RecurringRuleRow existing = await requireActiveRule(id);

    String? trimmedName;
    if (name != null) {
      trimmedName = _validateName(name);
    }

    final Money effectiveAmount =
        amount ?? Money.fromMinorUnits(existing.amountMinorUnits, existing.currencyCode);
    if (amount != null) {
      _validateAmount(amount);
    }

    final int effectiveInterval = interval ?? existing.interval;
    _validateInterval(effectiveInterval);

    final DateTime effectiveStart =
        startDate == null ? existing.startDate : normalizeRecurringDate(startDate);
    final DateTime? effectiveEnd = endDate.present
        ? (endDate.value == null ? null : normalizeRecurringDate(endDate.value!))
        : existing.endDate;
    _validateDateRange(effectiveStart, effectiveEnd);

    final String effectiveAccountId = accountId ?? existing.accountId;
    final String? effectiveDestinationAccountId =
        destinationAccountId.present ? destinationAccountId.value : existing.destinationAccountId;
    final RecurringRuleKind kindEnum = RecurringRuleKind.values.byName(existing.kind);

    await _validateAccounts(
      kind: kindEnum,
      accountId: effectiveAccountId,
      destinationAccountId: effectiveDestinationAccountId,
      currencyCode: effectiveAmount.currencyCode,
    );

    final DateTime now = DateTime.now().toUtc();
    await (_db.update(_db.recurringRules)..where((tbl) => tbl.id.equals(id))).write(
      RecurringRulesCompanion(
        name: trimmedName == null ? const Value<String>.absent() : Value<String>(trimmedName),
        amountMinorUnits: amount == null
            ? const Value<int>.absent()
            : Value<int>(amount.minorUnits),
        currencyCode:
            amount == null ? const Value<String>.absent() : Value<String>(amount.currencyCode),
        accountId: accountId == null ? const Value<String>.absent() : Value<String>(accountId),
        destinationAccountId: destinationAccountId,
        categoryId: categoryId,
        serviceIdentityKey: serviceIdentityKey,
        note: note,
        frequency:
            frequency == null ? const Value<String>.absent() : Value<String>(frequency.name),
        interval: interval == null ? const Value<int>.absent() : Value<int>(interval),
        startDate:
            startDate == null ? const Value<DateTime>.absent() : Value<DateTime>(effectiveStart),
        endDate: endDate.present ? Value<DateTime?>(effectiveEnd) : const Value<DateTime?>.absent(),
        notificationsEnabled: notificationsEnabled,
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Soft-deletes the rule row with id [id]. Per ADR-023: excluded from
  /// every active/upcoming provider from this point on, and can never
  /// post a new occurrence again ([postOccurrence] requires an active
  /// rule via [requireActiveRule]) -- but its already-posted
  /// `Transactions` rows and already-handled `RecurringOccurrences` rows
  /// are untouched.
  Future<void> softDelete(String id) {
    final DateTime now = DateTime.now().toUtc();
    return (_db.update(_db.recurringRules)..where((tbl) => tbl.id.equals(id))).write(
      RecurringRulesCompanion(deletedAt: Value<DateTime?>(now), updatedAt: Value<DateTime>(now)),
    );
  }

  /// All active (non-deleted) rules for [profileId], reactively.
  Stream<List<RecurringRuleRow>> watchActiveRules(String profileId) {
    final query = _db.select(_db.recurringRules)
      ..where((tbl) => tbl.profileId.equals(profileId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    return query.watch().map((rows) => rows.map(_withUtcDateTimes).toList());
  }

  /// The rule with id [id], reactively -- `null` if it doesn't exist OR
  /// has been soft-deleted.
  Stream<RecurringRuleRow?> watchById(String id) {
    final query = _db.select(_db.recurringRules)
      ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull());
    return query.watchSingleOrNull().map((row) => row == null ? null : _withUtcDateTimes(row));
  }

  /// The active rule with id [id]. Throws [RecurringRuleNotFoundException]
  /// if it doesn't exist or has been soft-deleted.
  Future<RecurringRuleRow> requireActiveRule(String id) async {
    final query = _db.select(_db.recurringRules)
      ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull());
    final RecurringRuleRow? row = await query.getSingleOrNull();
    if (row == null) {
      throw RecurringRuleNotFoundException(id);
    }
    return _withUtcDateTimes(row);
  }

  /// One-shot (non-reactive) list of every ACTIVE (non-soft-deleted)
  /// rule that references [accountId], either as its source
  /// ([RecurringRules.accountId]) or, for a transfer rule, its
  /// destination ([RecurringRules.destinationAccountId]) -- Account
  /// Lifecycle Checkpoint. What
  /// `AccountLifecycleService.closeAccount` reads (inside an
  /// `AppDatabase.transaction()` callback) to decide whether closing
  /// [accountId] is safe: a non-empty result blocks the close entirely
  /// rather than silently redirecting or deleting the rule(s) -- see
  /// that service's own doc for why. Never used to populate a selector.
  Future<List<RecurringRuleRow>> activeRulesReferencingAccountOnce(String accountId) async {
    final query = _db.select(_db.recurringRules)
      ..where(
        (tbl) =>
            tbl.deletedAt.isNull() &
            (tbl.accountId.equals(accountId) | tbl.destinationAccountId.equals(accountId)),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    final List<RecurringRuleRow> rows = await query.get();
    return rows.map(_withUtcDateTimes).toList();
  }
}
