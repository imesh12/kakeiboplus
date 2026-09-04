import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/budgets/domain/budget_month.dart';
import '../../currency/currency_registry.dart';
import '../../money/money.dart';
import '../app_database.dart';

/// Thrown when an attempt is made to persist a budget whose amount is
/// not strictly positive. A configured budget of zero is not a valid
/// state (see `docs/14_DECISION_LOG.md` ADR-021) -- this is thrown
/// before any write happens, never silently coerced or clamped.
class InvalidBudgetAmountException implements Exception {
  InvalidBudgetAmountException(this.amount);
  final Money amount;
  @override
  String toString() =>
      'InvalidBudgetAmountException: budget amount must be strictly positive, got $amount';
}

/// The repository behind Beta 1's budgets feature: creating/updating
/// overall and category monthly budgets, reading them back, and
/// soft-deleting them.
///
/// **Uniqueness is an application-layer invariant here, not a
/// database-enforced one** -- see `docs/14_DECISION_LOG.md` ADR-021,
/// which follows the same repository-layer-validation precedent ADR-019
/// established for [TransactionRepository]'s currency-match rule. This
/// class is the only sanctioned way to write a budget row:
/// [setOverallBudget] and [setCategoryBudget] are upserts, each looking
/// for an existing *active* (`deletedAt IS NULL`) row matching its
/// profile/currency/year/month(/category) key and updating it in place
/// if found, or inserting a new row if not. There is deliberately no
/// separate public "insert" method that could bypass this and create a
/// second active row for the same key. Because the uniqueness check only
/// ever considers active rows, deleting a budget and then setting a new
/// one for the same key is always safe -- the soft-deleted row is simply
/// ignored, never a conflict.
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  void _validateAmount(Money amount) {
    if (!amount.isPositive) {
      throw InvalidBudgetAmountException(amount);
    }
    // Throws ArgumentError if currencyCode isn't a known currency --
    // surfaces an unsupported currency immediately, at write time,
    // rather than only once something later tries to read it back.
    CurrencyRegistry.require(amount.currencyCode);
  }

  /// Creates or updates the profile's overall (whole-currency) budget for
  /// [month], in [amount]'s currency. Rejects a zero or negative
  /// [amount] (throws [InvalidBudgetAmountException]) and an unsupported
  /// currency code (throws [ArgumentError]).
  Future<String> setOverallBudget({
    required String profileId,
    required BudgetMonth month,
    required Money amount,
  }) {
    return _upsert(profileId: profileId, categoryId: null, month: month, amount: amount);
  }

  /// Creates or updates the profile's budget for [categoryId], for
  /// [month], in [amount]'s currency. Same validation as
  /// [setOverallBudget].
  Future<String> setCategoryBudget({
    required String profileId,
    required String categoryId,
    required BudgetMonth month,
    required Money amount,
  }) {
    return _upsert(profileId: profileId, categoryId: categoryId, month: month, amount: amount);
  }

  Future<String> _upsert({
    required String profileId,
    required String? categoryId,
    required BudgetMonth month,
    required Money amount,
  }) async {
    _validateAmount(amount);
    final DateTime now = DateTime.now().toUtc();

    final query = _db.select(_db.budgets)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profileId) &
            (categoryId == null ? tbl.categoryId.isNull() : tbl.categoryId.equals(categoryId)) &
            tbl.currencyCode.equals(amount.currencyCode) &
            tbl.year.equals(month.year) &
            tbl.month.equals(month.month) &
            tbl.deletedAt.isNull(),
      );
    final BudgetRow? existing = await query.getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.budgets)..where((tbl) => tbl.id.equals(existing.id))).write(
        BudgetsCompanion(
          amountMinorUnits: Value<int>(amount.minorUnits),
          updatedAt: Value<DateTime>(now),
        ),
      );
      return existing.id;
    }

    final String id = _uuid.v4();
    await _db.into(_db.budgets).insert(
          BudgetsCompanion.insert(
            id: id,
            profileId: profileId,
            categoryId: Value<String?>(categoryId),
            currencyCode: amount.currencyCode,
            year: month.year,
            month: month.month,
            amountMinorUnits: amount.minorUnits,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// The active overall budget for [profileId]/[currencyCode]/[month],
  /// reactively -- `null` in the stream means "not configured".
  Stream<BudgetRow?> watchActiveOverallBudget({
    required String profileId,
    required String currencyCode,
    required BudgetMonth month,
  }) {
    final query = _db.select(_db.budgets)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profileId) &
            tbl.categoryId.isNull() &
            tbl.currencyCode.equals(currencyCode) &
            tbl.year.equals(month.year) &
            tbl.month.equals(month.month) &
            tbl.deletedAt.isNull(),
      );
    return query.watchSingleOrNull();
  }

  /// The active category budget for
  /// [profileId]/[categoryId]/[currencyCode]/[month], reactively.
  Stream<BudgetRow?> watchActiveCategoryBudget({
    required String profileId,
    required String categoryId,
    required String currencyCode,
    required BudgetMonth month,
  }) {
    final query = _db.select(_db.budgets)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profileId) &
            tbl.categoryId.equals(categoryId) &
            tbl.currencyCode.equals(currencyCode) &
            tbl.year.equals(month.year) &
            tbl.month.equals(month.month) &
            tbl.deletedAt.isNull(),
      );
    return query.watchSingleOrNull();
  }

  /// All active (non-deleted) budgets for [profileId]/[month], across
  /// every currency and including both the overall budget and any
  /// category budgets -- what the budget management screen lists.
  Stream<List<BudgetRow>> watchActiveForMonth({
    required String profileId,
    required BudgetMonth month,
  }) {
    final query = _db.select(_db.budgets)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profileId) &
            tbl.year.equals(month.year) &
            tbl.month.equals(month.month) &
            tbl.deletedAt.isNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.currencyCode)]);
    return query.watch();
  }

  /// Soft-deletes the budget row with id [id]. A subsequent
  /// [setOverallBudget]/[setCategoryBudget] call for the same key is
  /// unaffected -- it only ever looks at active rows -- so recreating a
  /// deleted budget always succeeds.
  Future<void> softDelete(String id) {
    final DateTime now = DateTime.now().toUtc();
    return (_db.update(_db.budgets)..where((tbl) => tbl.id.equals(id))).write(
      BudgetsCompanion(deletedAt: Value<DateTime?>(now), updatedAt: Value<DateTime>(now)),
    );
  }
}
