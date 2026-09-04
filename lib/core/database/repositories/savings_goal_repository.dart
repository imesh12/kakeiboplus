import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/goals/domain/goal_target_date.dart';
import '../../currency/currency_registry.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';

/// Thrown when an attempt is made to persist a savings goal whose target
/// amount is not strictly positive. Mirrors `BudgetRepository`'s
/// `InvalidBudgetAmountException` -- see `docs/14_DECISION_LOG.md`
/// ADR-022.
class InvalidSavingsGoalTargetAmountException implements Exception {
  InvalidSavingsGoalTargetAmountException(this.amount);
  final Money amount;
  @override
  String toString() => 'InvalidSavingsGoalTargetAmountException: target amount must be strictly '
      'positive, got $amount';
}

/// Thrown when an attempt is made to persist a savings goal whose name
/// is empty or contains only whitespace. See `docs/14_DECISION_LOG.md`
/// ADR-022.
class InvalidSavingsGoalNameException implements Exception {
  InvalidSavingsGoalNameException(this.name);
  final String name;
  @override
  String toString() =>
      'InvalidSavingsGoalNameException: name must not be empty or whitespace-only, got "$name"';
}

/// Thrown when [SavingsGoalRepository.requireActiveGoal] (or an
/// operation that depends on it, such as recording a contribution) is
/// asked for a goal id that either does not exist or has been
/// soft-deleted. Per `docs/14_DECISION_LOG.md` ADR-022, a soft-deleted
/// goal is never treated as active by any repository or provider,
/// regardless of what the caller believes.
class SavingsGoalNotFoundException implements Exception {
  SavingsGoalNotFoundException(this.id);
  final String id;
  @override
  String toString() => 'SavingsGoalNotFoundException: no active savings goal with id "$id"';
}

/// The repository behind Beta 1 Task 3's savings goals feature: creating,
/// updating, and soft-deleting goals, and reading them back.
///
/// **A goal's currency is permanently anchored at creation** --
/// [updateGoal] never changes it: passing a [Money] `targetAmount`
/// denominated in a different currency than the goal's throws
/// [CurrencyMismatchException] and leaves the stored row untouched (see
/// `docs/14_DECISION_LOG.md` ADR-022, following the same
/// reject-rather-than-coerce precedent [Money] arithmetic and
/// `AccountRepository.createAccount` already establish).
///
/// **A soft-deleted goal is never active** -- this is enforced here, not
/// only trusted to UI callers. [watchById] and [requireActiveGoal] both
/// exclude a soft-deleted row exactly as if it no longer existed, the
/// same way [watchActiveGoals] already did -- this repository has no
/// read path that can return a deleted goal as if it were live. See
/// ADR-022 and `SavingsGoalContributionRepository`, which relies on
/// [requireActiveGoal] to refuse a contribution against a deleted goal.
class SavingsGoalRepository {
  SavingsGoalRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// Drift's default (non-text) `DateTime` column storage -- unix
  /// seconds since the epoch, the only mode this project uses (no
  /// `store_date_time_values_as_text` override) -- round-trips the
  /// correct *instant* but reads every value back tagged as local time
  /// (`DateTime.isUtc == false`), never UTC, regardless of how it was
  /// written. Every `DateTime` this table stores (`targetDate`,
  /// `createdAt`, `updatedAt`, `deletedAt`) is written UTC-tagged (see
  /// [createGoal]/[updateGoal] and `normalizeCalendarDateToUtc`), so
  /// this re-tags each one back to UTC on the way out -- `.toUtc()`
  /// only changes the tag/displayed calendar fields, it never moves the
  /// underlying instant, so this cannot alter any already-persisted
  /// data or shift the calendar date `normalizeCalendarDateToUtc`
  /// selected. Without this, a caller comparing a read-back row against
  /// a UTC-tagged `DateTime` (as every test in
  /// `savings_goal_repository_test.dart` does) sees a same-instant
  /// value that nonetheless fails `==`, since Dart's `DateTime.==`
  /// distinguishes UTC-tagged from local-tagged values even when they
  /// represent the same moment.
  static SavingsGoalRow _withUtcDateTimes(SavingsGoalRow row) {
    return row.copyWith(
      targetDate: Value<DateTime?>(row.targetDate?.toUtc()),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      deletedAt: Value<DateTime?>(row.deletedAt?.toUtc()),
    );
  }

  String _validateName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw InvalidSavingsGoalNameException(name);
    }
    return trimmed;
  }

  void _validateTargetAmount(Money amount) {
    if (!amount.isPositive) {
      throw InvalidSavingsGoalTargetAmountException(amount);
    }
    // Throws ArgumentError if currencyCode isn't a known currency --
    // surfaces an unsupported currency immediately, at write time,
    // rather than only once something later tries to read it back.
    CurrencyRegistry.require(amount.currencyCode);
  }

  /// Creates a new savings goal. [name] is trimmed and must not be empty
  /// or whitespace-only ([InvalidSavingsGoalNameException]);
  /// [targetAmount] must be strictly positive in a supported currency
  /// ([InvalidSavingsGoalTargetAmountException]); [targetDate], if
  /// given, is normalized via [normalizeCalendarDateToUtc] -- see that
  /// function's doc comment for why this never goes through `.toUtc()`.
  Future<String> createGoal({
    required String profileId,
    required String name,
    required Money targetAmount,
    DateTime? targetDate,
  }) async {
    final String trimmedName = _validateName(name);
    _validateTargetAmount(targetAmount);

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.savingsGoals).insert(
          SavingsGoalsCompanion.insert(
            id: id,
            profileId: profileId,
            name: trimmedName,
            targetAmountMinorUnits: targetAmount.minorUnits,
            currencyCode: targetAmount.currencyCode,
            targetDate: Value<DateTime?>(
              targetDate == null ? null : normalizeCalendarDateToUtc(targetDate),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Updates an existing, active savings goal. Every parameter besides
  /// [id] is optional and independently "leave unchanged" when omitted:
  /// [name] and [targetAmount] use plain `null` for that (matching every
  /// other repository's update method in this codebase); [targetDate]
  /// uses drift's own [Value] sentinel, which this project already
  /// relies on everywhere else to distinguish "don't touch" from "set"
  /// in a Companion update -- `Value.absent()` (the default) leaves the
  /// target date unchanged, `Value(null)` explicitly clears it, and
  /// `Value(someDate)` replaces it (normalized via
  /// [normalizeCalendarDateToUtc]).
  ///
  /// Throws [SavingsGoalNotFoundException] if [id] doesn't name an
  /// active goal. Throws [InvalidSavingsGoalNameException] /
  /// [InvalidSavingsGoalTargetAmountException] for an invalid [name] /
  /// [targetAmount], same rules as [createGoal]. Throws
  /// [CurrencyMismatchException] if [targetAmount] is denominated in a
  /// different currency than the goal's -- a goal's currency can never
  /// change after creation (ADR-022). Every validation runs BEFORE any
  /// write, so a rejected update leaves the stored row completely
  /// unchanged.
  Future<void> updateGoal({
    required String id,
    String? name,
    Money? targetAmount,
    Value<DateTime?> targetDate = const Value<DateTime?>.absent(),
  }) async {
    final SavingsGoalRow existing = await requireActiveGoal(id);

    String? trimmedName;
    if (name != null) {
      trimmedName = _validateName(name);
    }

    if (targetAmount != null) {
      _validateTargetAmount(targetAmount);
      if (targetAmount.currencyCode != existing.currencyCode) {
        throw CurrencyMismatchException(existing.currencyCode, targetAmount.currencyCode);
      }
    }

    final DateTime now = DateTime.now().toUtc();
    await (_db.update(_db.savingsGoals)..where((tbl) => tbl.id.equals(id))).write(
      SavingsGoalsCompanion(
        name: trimmedName == null ? const Value<String>.absent() : Value<String>(trimmedName),
        targetAmountMinorUnits: targetAmount == null
            ? const Value<int>.absent()
            : Value<int>(targetAmount.minorUnits),
        targetDate: targetDate.present
            ? Value<DateTime?>(
                targetDate.value == null ? null : normalizeCalendarDateToUtc(targetDate.value!),
              )
            : const Value<DateTime?>.absent(),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Soft-deletes the goal row with id [id]. Per ADR-022, this does NOT
  /// cascade to `SavingsGoalContributions` -- historical contribution
  /// rows remain physically present -- but every read path in this
  /// repository (and `SavingsGoalContributionRepository`) treats the
  /// parent goal as gone from this point on.
  Future<void> softDeleteGoal(String id) {
    final DateTime now = DateTime.now().toUtc();
    return (_db.update(_db.savingsGoals)..where((tbl) => tbl.id.equals(id))).write(
      SavingsGoalsCompanion(deletedAt: Value<DateTime?>(now), updatedAt: Value<DateTime>(now)),
    );
  }

  /// All active (non-deleted) goals for [profileId], reactively, oldest
  /// first. A caller that needs a different order (e.g. the
  /// priority/Home selection in `savings_goal_providers.dart`) re-sorts
  /// this list itself rather than relying on this ordering.
  Stream<List<SavingsGoalRow>> watchActiveGoals(String profileId) {
    final query = _db.select(_db.savingsGoals)
      ..where((tbl) => tbl.profileId.equals(profileId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    return query.watch().map((rows) => rows.map(_withUtcDateTimes).toList());
  }

  /// The goal with id [id], reactively -- `null` if it doesn't exist OR
  /// has been soft-deleted (ADR-022: a deleted goal reads back as gone
  /// through this repository, not merely by UI convention).
  Stream<SavingsGoalRow?> watchById(String id) {
    final query = _db.select(_db.savingsGoals)
      ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull());
    return query.watchSingleOrNull().map((row) => row == null ? null : _withUtcDateTimes(row));
  }

  /// The active goal with id [id]. Throws [SavingsGoalNotFoundException]
  /// if it doesn't exist or has been soft-deleted. This is the
  /// application-layer invariant `SavingsGoalContributionRepository`
  /// relies on to refuse a contribution against a deleted goal -- see
  /// ADR-022.
  Future<SavingsGoalRow> requireActiveGoal(String id) async {
    final query = _db.select(_db.savingsGoals)
      ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull());
    final SavingsGoalRow? row = await query.getSingleOrNull();
    if (row == null) {
      throw SavingsGoalNotFoundException(id);
    }
    return _withUtcDateTimes(row);
  }
}
