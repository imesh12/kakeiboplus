import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/recurring/domain/recurring_occurrence_status.dart';
import '../../../features/recurring/domain/recurring_rule_kind.dart';
import '../../../features/recurring/domain/recurring_schedule.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'recurring_rule_repository.dart';
import 'transaction_repository.dart';

/// Thrown by [RecurringOccurrenceRepository.postOccurrence] or
/// [RecurringOccurrenceRepository.skipOccurrence] when the
/// (`ruleId`, `scheduledDate`) pair already has a handled occurrence --
/// regardless of that occurrence's status. Posting an already-posted OR
/// already-skipped occurrence is rejected; skipping an already-posted OR
/// already-skipped occurrence is rejected. There is no "overwrite" path
/// -- see `docs/14_DECISION_LOG.md` ADR-023.
class RecurringOccurrenceAlreadyHandledException implements Exception {
  RecurringOccurrenceAlreadyHandledException({
    required this.ruleId,
    required this.scheduledDate,
    required this.existingStatus,
  });

  final String ruleId;
  final DateTime scheduledDate;

  /// The status ('posted' | 'skipped') the existing occurrence already
  /// has.
  final String existingStatus;

  @override
  String toString() =>
      'RecurringOccurrenceAlreadyHandledException: rule "$ruleId" already has a '
      '$existingStatus occurrence for $scheduledDate';
}

/// The repository behind Beta 1 Task 4A's handled-occurrence ledger:
/// posting a due date (creating a real `Transactions` row via
/// [TransactionRepository] -- never a parallel calculation engine) or
/// explicitly skipping it, and reading handled occurrences back.
///
/// **Uniqueness is an application-layer invariant here, not a
/// database-enforced one** -- same precedent
/// `BudgetRepository`/`SavingsGoalRepository` already established: at
/// most one `RecurringOccurrences` row exists per (`ruleId`,
/// `scheduledDate`) pair. Both [postOccurrence] and [skipOccurrence]
/// check for ANY existing row for that pair (posted or skipped) and
/// throw [RecurringOccurrenceAlreadyHandledException] rather than
/// creating a second row.
///
/// **Posting is atomic.** The real ledger transaction and the
/// occurrence row are written inside a single `AppDatabase.transaction`
/// block -- if either write fails, both roll back together, so a failed
/// post never leaves a `Transactions` row with no matching occurrence,
/// or vice versa.
class RecurringOccurrenceRepository {
  RecurringOccurrenceRepository(this._db, this._ruleRepository, this._transactionRepository);

  final AppDatabase _db;
  final RecurringRuleRepository _ruleRepository;
  final TransactionRepository _transactionRepository;
  static const Uuid _uuid = Uuid();

  /// See `RecurringRuleRepository._withUtcDateTimes`'s doc comment.
  static RecurringOccurrenceRow _withUtcDateTimes(RecurringOccurrenceRow row) {
    return row.copyWith(
      scheduledDate: row.scheduledDate.toUtc(),
      handledAt: row.handledAt.toUtc(),
      createdAt: row.createdAt.toUtc(),
    );
  }

  Future<RecurringOccurrenceRow?> _existingHandled({
    required String ruleId,
    required DateTime scheduledDate,
  }) {
    final query = _db.select(_db.recurringOccurrences)
      ..where((tbl) => tbl.ruleId.equals(ruleId) & tbl.scheduledDate.equals(scheduledDate));
    return query.getSingleOrNull();
  }

  Future<void> _rejectIfAlreadyHandled({
    required String ruleId,
    required DateTime scheduledDate,
  }) async {
    final RecurringOccurrenceRow? existing = await _existingHandled(
      ruleId: ruleId,
      scheduledDate: scheduledDate,
    );
    if (existing != null) {
      throw RecurringOccurrenceAlreadyHandledException(
        ruleId: ruleId,
        scheduledDate: scheduledDate,
        existingStatus: existing.status,
      );
    }
  }

  /// Posts [scheduledDateUtc] for [ruleId]: creates a real `Transactions`
  /// row via the existing [TransactionRepository] paths (expense ->
  /// [TransactionRepository.recordExpense], income ->
  /// [TransactionRepository.recordIncome], transfer ->
  /// [TransactionRepository.recordTransfer] -- so every existing
  /// transaction-layer invariant, including same-currency transfer
  /// enforcement and transfers being excluded from income/spending
  /// totals, applies unchanged), then records a 'posted'
  /// `RecurringOccurrences` row carrying that transaction's id.
  ///
  /// Throws [RecurringRuleNotFoundException] if [ruleId] doesn't name an
  /// active rule (a soft-deleted rule can never post again). Throws
  /// [RecurringOccurrenceAlreadyHandledException] if this
  /// (`ruleId`, `scheduledDate`) pair already has a handled occurrence,
  /// posted or skipped -- posting the same occurrence twice is always
  /// rejected. Returns the new `RecurringOccurrences` row's id.
  Future<String> postOccurrence({required String ruleId, required DateTime scheduledDateUtc}) async {
    final DateTime scheduledDate = normalizeRecurringDate(scheduledDateUtc);
    final RecurringRuleRow rule = await _ruleRepository.requireActiveRule(ruleId);
    await _rejectIfAlreadyHandled(ruleId: ruleId, scheduledDate: scheduledDate);

    final Money amount = Money.fromMinorUnits(rule.amountMinorUnits, rule.currencyCode);
    final RecurringRuleKind kind = RecurringRuleKind.values.byName(rule.kind);
    final String occurrenceId = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();

    return _db.transaction(() async {
      // Re-check inside the transaction -- defensive against a write
      // that landed between the check above and here.
      await _rejectIfAlreadyHandled(ruleId: ruleId, scheduledDate: scheduledDate);

      final String transactionId = switch (kind) {
        RecurringRuleKind.expense => await _transactionRepository.recordExpense(
            profileId: rule.profileId,
            accountId: rule.accountId,
            amount: amount,
            categoryId: rule.categoryId,
            note: rule.note,
            occurredAtUtc: scheduledDate,
          ),
        RecurringRuleKind.income => await _transactionRepository.recordIncome(
            profileId: rule.profileId,
            accountId: rule.accountId,
            amount: amount,
            categoryId: rule.categoryId,
            note: rule.note,
            occurredAtUtc: scheduledDate,
          ),
        RecurringRuleKind.transfer => await _transactionRepository.recordTransfer(
            profileId: rule.profileId,
            sourceAccountId: rule.accountId,
            destinationAccountId: rule.destinationAccountId!,
            amount: amount,
            note: rule.note,
            occurredAtUtc: scheduledDate,
          ),
      };

      await _db.into(_db.recurringOccurrences).insert(
            RecurringOccurrencesCompanion.insert(
              id: occurrenceId,
              ruleId: ruleId,
              scheduledDate: scheduledDate,
              status: RecurringOccurrenceStatus.posted.name,
              transactionId: Value<String?>(transactionId),
              handledAt: now,
              createdAt: now,
            ),
          );
      return occurrenceId;
    });
  }

  /// Records [scheduledDateUtc] for [ruleId] as explicitly skipped --
  /// creates NO `Transactions` row. Throws
  /// [RecurringRuleNotFoundException] if [ruleId] doesn't name an active
  /// rule, and [RecurringOccurrenceAlreadyHandledException] if this pair
  /// already has a handled occurrence, posted or skipped. Returns the
  /// new `RecurringOccurrences` row's id.
  Future<String> skipOccurrence({required String ruleId, required DateTime scheduledDateUtc}) async {
    final DateTime scheduledDate = normalizeRecurringDate(scheduledDateUtc);
    // Confirms the rule exists and is active, same as postOccurrence --
    // a soft-deleted rule can't accrue new handled occurrences either.
    await _ruleRepository.requireActiveRule(ruleId);
    await _rejectIfAlreadyHandled(ruleId: ruleId, scheduledDate: scheduledDate);

    final String occurrenceId = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();

    return _db.transaction(() async {
      await _rejectIfAlreadyHandled(ruleId: ruleId, scheduledDate: scheduledDate);
      await _db.into(_db.recurringOccurrences).insert(
            RecurringOccurrencesCompanion.insert(
              id: occurrenceId,
              ruleId: ruleId,
              scheduledDate: scheduledDate,
              status: RecurringOccurrenceStatus.skipped.name,
              handledAt: now,
              createdAt: now,
            ),
          );
      return occurrenceId;
    });
  }

  /// Every handled occurrence for [ruleId], reactively, newest scheduled
  /// date first. Untouched by [RecurringRuleRepository.softDelete] --
  /// historical occurrence records remain exactly as they were.
  Stream<List<RecurringOccurrenceRow>> watchHandledForRule(String ruleId) {
    final query = _db.select(_db.recurringOccurrences)
      ..where((tbl) => tbl.ruleId.equals(ruleId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDate)]);
    return query.watch().map((rows) => rows.map(_withUtcDateTimes).toList());
  }

  /// Every handled occurrence across every rule id in [ruleIds],
  /// reactively -- the multi-rule counterpart to [watchHandledForRule],
  /// used to derive "which scheduled dates already have a row" across a
  /// whole profile's active rules without one stream per rule. Returns
  /// an already-completed empty stream for an empty [ruleIds].
  Stream<List<RecurringOccurrenceRow>> watchHandledForRules(List<String> ruleIds) {
    if (ruleIds.isEmpty) {
      return Stream<List<RecurringOccurrenceRow>>.value(const <RecurringOccurrenceRow>[]);
    }
    final query = _db.select(_db.recurringOccurrences)
      ..where((tbl) => tbl.ruleId.isIn(ruleIds));
    return query.watch().map((rows) => rows.map(_withUtcDateTimes).toList());
  }
}
