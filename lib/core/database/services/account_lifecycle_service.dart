import '../../finance/financial_account_subtype.dart';
import '../app_database.dart';
import '../repositories/account_repository.dart';
import '../repositories/payment_instrument_repository.dart';
import '../repositories/recurring_rule_repository.dart';

/// Thrown by [AccountLifecycleService.closeAccount] when [accountId] is
/// already closed (or never existed as an active account) at the moment
/// of the call -- never a silent no-op, same discipline
/// [AccountNotFoundException] already applies elsewhere in this schema.
class AccountAlreadyClosedException implements Exception {
  const AccountAlreadyClosedException(this.accountId);

  final String accountId;

  @override
  String toString() => 'AccountAlreadyClosedException: account $accountId is already closed';
}

/// Thrown by [AccountLifecycleService.reactivateAccount] when
/// [accountId] is already active at the moment of the call.
class AccountNotClosedException implements Exception {
  const AccountNotClosedException(this.accountId);

  final String accountId;

  @override
  String toString() => 'AccountNotClosedException: account $accountId is not closed';
}

/// Thrown by [AccountLifecycleService.closeAccount] when one or more
/// still-active [RecurringRuleRow]s reference [accountId] (as source or,
/// for a transfer rule, destination). The Account Lifecycle Checkpoint's
/// own brief is explicit that closing an account must never silently
/// redirect or delete a recurring rule that depends on it -- since
/// today's `RecurringRuleRepository`/`RecurringRule` domain defines no
/// behavior for "the account a rule depends on became unavailable",
/// [closeAccount] blocks entirely and surfaces [blockingRuleCount]
/// rather than inventing one. The presentation layer is expected to
/// translate this into a clear, localized, non-technical message
/// telling the user to change or delete those recurring rules first.
class AccountHasActiveRecurringRulesException implements Exception {
  const AccountHasActiveRecurringRulesException(this.accountId, this.blockingRuleCount);

  final String accountId;
  final int blockingRuleCount;

  @override
  String toString() =>
      'AccountHasActiveRecurringRulesException: account $accountId is referenced by '
      '$blockingRuleCount active recurring rule(s)';
}

/// Account Lifecycle Checkpoint (docs/20 §13.12.1's own deferral -- this
/// is that later checkpoint): the single entry point for closing
/// ("deactivating") and reopening ("reactivating") an existing
/// [AccountRow], following the exact same discipline
/// `AccountCreationService` already established for atomic multi-record
/// account composition -- this class does not duplicate or re-implement
/// any repository's own validation or query logic, it only SEQUENCES
/// already-existing (or, for the two new one-shot lookups this
/// checkpoint added, minimally-added) repository calls inside one
/// `AppDatabase.transaction()`, so a failure at any step rolls back
/// every write the same call already made.
///
/// **What "closed" means here, precisely:** [AccountRepository.softDelete]
/// (renamed at the UI layer to "Close account" / a credit-card-specific
/// wording) sets [AccountRow.isActive] to `false` and stamps
/// [AccountRow.deletedAt] -- but unlike every OTHER `deletedAt` in this
/// schema, an account's is reversible via [AccountRepository.reactivate]
/// and the row remains fully resolvable
/// (`AccountRepository.watchById`/`watchAllForProfile`) for history and
/// reactivation. Closing an account NEVER:
///  - deletes, rewrites, or resets any `Transactions` row or the
///    account's derived balance (still computed the same way, from the
///    same opening balance + transaction history, regardless of
///    [AccountRow.isActive]);
///  - creates a balancing/reversal transaction;
///  - changes [AccountRow.balanceClass]/[AccountRow.subtype]/
///    [AccountRow.currencyCode]/[AccountRow.openingBalanceMinorUnits]/
///    [AccountRow.name]/[AccountRow.type] (this service calls neither
///    `AccountRepository.createAccount`/`createClassifiedAccount` nor
///    `updateAccount` -- it has no way to touch any of those fields);
///  - deletes a `CreditFacilityDetails`/`DepositDetails` row (this
///    service never touches either table at all -- both are keyed by
///    `accountId` alone and are correct to leave exactly as they are,
///    closed or not).
///
/// **Credit-card accounts only:** [closeAccount] additionally archives
/// (`PaymentInstrumentRepository.softDelete`) every currently-active
/// `PaymentInstrument` linked to the account, in the SAME transaction,
/// so a closed card immediately disappears from every "pick an
/// instrument" selector while remaining resolvable for its historical
/// transactions' attribution (`PaymentInstrumentRepository
/// .findByIdIncludingDeleted`) -- exactly the existing archived-
/// instrument convention docs/20 §13.9 already documents, just now
/// reachable by closing the account itself rather than only by
/// archiving the instrument directly. [reactivateAccount] restores
/// exactly the instrument(s) it archived, and no others.
///
/// **Recurring rules:** [closeAccount] blocks entirely -- see
/// [AccountHasActiveRecurringRulesException] -- rather than inventing
/// any redirect/delete behavior undefined by today's architecture.
///
/// **Deferred, deliberately:** account deletion (hard or otherwise) is
/// NOT part of this class -- the Account Lifecycle Checkpoint's own
/// brief requires deferring it unless safe deletion can be proven for
/// an unused, dependency-free account, and this checkpoint's audit
/// found no existing mechanism that proves that safely (see the
/// checkpoint's final report). `AccountRepository.softDelete` already
/// existed before this checkpoint and is reused here as-is for "close",
/// not redefined as a delete.
class AccountLifecycleService {
  AccountLifecycleService({
    required AppDatabase db,
    required AccountRepository accountRepository,
    required PaymentInstrumentRepository paymentInstrumentRepository,
    required RecurringRuleRepository recurringRuleRepository,
  })  : _db = db,
        _accountRepository = accountRepository,
        _paymentInstrumentRepository = paymentInstrumentRepository,
        _recurringRuleRepository = recurringRuleRepository;

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  final PaymentInstrumentRepository _paymentInstrumentRepository;
  final RecurringRuleRepository _recurringRuleRepository;

  /// Closes [accountId] -- see this class's own doc for exactly what
  /// that does and does not do. Throws [AccountAlreadyClosedException]
  /// if it's already closed, and [AccountHasActiveRecurringRulesException]
  /// if any active recurring rule still references it (as source or
  /// transfer destination) -- in either case nothing is written.
  Future<void> closeAccount({required String accountId}) {
    return _db.transaction(() async {
      final AccountRow account = await _accountRepository.requireById(accountId);
      if (!account.isActive || account.deletedAt != null) {
        throw AccountAlreadyClosedException(accountId);
      }

      final List<RecurringRuleRow> blockingRules =
          await _recurringRuleRepository.activeRulesReferencingAccountOnce(accountId);
      if (blockingRules.isNotEmpty) {
        throw AccountHasActiveRecurringRulesException(accountId, blockingRules.length);
      }

      await _accountRepository.softDelete(accountId);

      if (account.subtypeValue == FinancialAccountSubtype.creditCard) {
        final List<PaymentInstrumentRow> instruments =
            await _paymentInstrumentRepository.activeForAccountOnce(accountId);
        for (final PaymentInstrumentRow instrument in instruments) {
          await _paymentInstrumentRepository.softDelete(instrument.id);
        }
      }
    });
  }

  /// Reactivates a previously-closed [accountId] -- see this class's own
  /// doc for exactly what that does and does not do. Throws
  /// [AccountNotClosedException] if it's already active.
  Future<void> reactivateAccount({required String accountId}) {
    return _db.transaction(() async {
      final AccountRow account = await _accountRepository.requireById(accountId);
      if (account.isActive && account.deletedAt == null) {
        throw AccountNotClosedException(accountId);
      }

      await _accountRepository.reactivate(accountId);

      if (account.subtypeValue == FinancialAccountSubtype.creditCard) {
        final List<PaymentInstrumentRow> instruments =
            await _paymentInstrumentRepository.allForAccountOnce(accountId);
        for (final PaymentInstrumentRow instrument in instruments) {
          if (instrument.deletedAt != null) {
            await _paymentInstrumentRepository.restore(instrument.id);
          }
        }
      }
    });
  }
}
