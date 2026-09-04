import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'savings_goal_repository.dart';

/// Thrown when an attempt is made to record a contribution whose amount
/// is not strictly positive. Beta 1 has no "withdrawal"/negative
/// contribution -- see `docs/14_DECISION_LOG.md` ADR-022.
class InvalidSavingsGoalContributionAmountException implements Exception {
  InvalidSavingsGoalContributionAmountException(this.amount);
  final Money amount;
  @override
  String toString() =>
      'InvalidSavingsGoalContributionAmountException: contribution amount must be strictly '
      'positive, got $amount';
}

/// The repository behind a savings goal's contribution ledger: an
/// explicit, append-only (Beta 1 supports deleting a contribution but
/// not editing one) record of every amount put toward a goal.
/// Deliberately creates NO `Transactions` row -- a contribution has no
/// income/expense/transfer side effect (`docs/14_DECISION_LOG.md`
/// ADR-022).
///
/// Depends on [SavingsGoalRepository] (constructor-injected, mirroring
/// `TransactionRepository`'s dependency on `AccountRepository`) so
/// [addContribution] can enforce, here at the repository layer rather
/// than only trusting the UI, that the parent goal (a) exists, (b) is
/// still active -- not soft-deleted -- and (c) shares the contribution's
/// currency. See ADR-022's application-layer-invariant precedent.
class SavingsGoalContributionRepository {
  SavingsGoalContributionRepository(this._db, this._goalRepository);

  final AppDatabase _db;
  final SavingsGoalRepository _goalRepository;
  static const Uuid _uuid = Uuid();

  /// Same Drift default-`DateTime`-storage caveat as
  /// `SavingsGoalRepository._withUtcDateTimes` -- the instant round-trips
  /// correctly but is read back tagged local, not UTC. `contributedAt`
  /// and `createdAt` are always written UTC-tagged (see
  /// [addContribution]), so this re-tags them back to UTC on the way
  /// out; `.toUtc()` never moves the underlying instant, so this cannot
  /// alter any already-persisted data.
  static SavingsGoalContributionRow _withUtcDateTimes(SavingsGoalContributionRow row) {
    return row.copyWith(
      contributedAt: row.contributedAt.toUtc(),
      createdAt: row.createdAt.toUtc(),
      deletedAt: Value<DateTime?>(row.deletedAt?.toUtc()),
    );
  }

  /// Records a contribution of [amount] toward [goalId]. Throws
  /// [InvalidSavingsGoalContributionAmountException] if [amount] isn't
  /// strictly positive; throws [SavingsGoalNotFoundException] (from
  /// [SavingsGoalRepository.requireActiveGoal]) if [goalId] doesn't name
  /// an active goal; throws [CurrencyMismatchException] if [amount]'s
  /// currency doesn't match the goal's. Every check runs before any
  /// write.
  ///
  /// [contributedAt], if given, is normalized to a UTC instant -- this
  /// column IS a genuine instant, unlike a goal's `targetDate` (see
  /// `goal_target_date.dart`'s doc comments for why those two use
  /// different normalization rules). If omitted, defaults to
  /// `DateTime.now().toUtc()` at call time, matching every other
  /// repository's convention in this codebase -- there is no separate
  /// clock abstraction to inject. Beta 1's UI never passes
  /// [contributedAt] (no backdating yet); it exists so repository tests
  /// can be deterministic.
  Future<String> addContribution({
    required String goalId,
    required Money amount,
    DateTime? contributedAt,
  }) async {
    if (!amount.isPositive) {
      throw InvalidSavingsGoalContributionAmountException(amount);
    }

    final SavingsGoalRow goal = await _goalRepository.requireActiveGoal(goalId);
    if (amount.currencyCode != goal.currencyCode) {
      throw CurrencyMismatchException(goal.currencyCode, amount.currencyCode);
    }

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.savingsGoalContributions).insert(
          SavingsGoalContributionsCompanion.insert(
            id: id,
            goalId: goalId,
            amountMinorUnits: amount.minorUnits,
            currencyCode: amount.currencyCode,
            contributedAt: contributedAt?.toUtc() ?? now,
            createdAt: now,
          ),
        );
    return id;
  }

  /// Soft-deletes the contribution row with id [id]. Beta 1 supports
  /// deleting a contribution but not editing one (ADR-022).
  Future<void> softDeleteContribution(String id) {
    return (_db.update(_db.savingsGoalContributions)..where((tbl) => tbl.id.equals(id))).write(
      SavingsGoalContributionsCompanion(deletedAt: Value<DateTime?>(DateTime.now().toUtc())),
    );
  }

  /// Active (non-deleted) contributions for [goalId], reactively, newest
  /// first -- the goal detail screen's contribution history order.
  Stream<List<SavingsGoalContributionRow>> watchActiveForGoal(String goalId) {
    final query = _db.select(_db.savingsGoalContributions)
      ..where((tbl) => tbl.goalId.equals(goalId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.contributedAt)]);
    return query.watch().map((rows) => rows.map(_withUtcDateTimes).toList());
  }

  /// Active (non-deleted) contributions across every goal id in
  /// [goalIds], reactively -- the multi-goal counterpart to
  /// [watchActiveForGoal], used by
  /// `lib/features/goals/presentation/savings_goal_providers.dart` to
  /// derive every active goal's `saved` total from a single query rather
  /// than one stream per goal. Returns an already-completed empty stream
  /// for an empty [goalIds] (never issues a `WHERE id IN ()` query).
  Stream<List<SavingsGoalContributionRow>> watchActiveForGoals(List<String> goalIds) {
    if (goalIds.isEmpty) {
      return Stream<List<SavingsGoalContributionRow>>.value(const <SavingsGoalContributionRow>[]);
    }
    final query = _db.select(_db.savingsGoalContributions)
      ..where((tbl) => tbl.goalId.isIn(goalIds) & tbl.deletedAt.isNull());
    return query.watch().map((rows) => rows.map(_withUtcDateTimes).toList());
  }

  /// Sum of active (non-deleted) contributions for [goalId], reactively,
  /// as [Money] in [currencyCode] -- what `goalCalculationProvider` feeds
  /// into `SavingsGoalCalculator.evaluate` as `saved`. Emits
  /// `Money.zero(currencyCode)` for a goal with no contributions yet,
  /// never `null`.
  Stream<Money> watchActiveTotalForGoal({required String goalId, required String currencyCode}) {
    return watchActiveForGoal(goalId).map((rows) {
      final int totalMinorUnits = rows.fold<int>(0, (sum, row) => sum + row.amountMinorUnits);
      return Money.fromMinorUnits(totalMinorUnits, currencyCode);
    });
  }
}
