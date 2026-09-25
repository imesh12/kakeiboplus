import '../../finance/account_creation_kind.dart';
import '../../finance/card_network.dart';
import '../../finance/deposit_compounding_frequency.dart';
import '../../finance/deposit_installment_frequency.dart';
import '../../finance/deposit_interest_method.dart';
import '../../finance/deposit_term_unit.dart';
import '../../finance/deposit_type.dart';
import '../../finance/payment_instrument_type.dart';
import '../../money/money.dart';
import '../app_database.dart';
import '../repositories/account_repository.dart';
import '../repositories/credit_facility_repository.dart';
import '../repositories/deposit_repository.dart';
import '../repositories/financial_institution_repository.dart';
import '../repositories/payment_instrument_repository.dart';

/// The three ids [AccountCreationService.createCreditCardAccount]
/// composes -- one row each in `Accounts`, `CreditFacilityDetails`, and
/// `PaymentInstruments`, all created inside the same transaction (see
/// that method's own doc).
class CreditCardCreationResult {
  const CreditCardCreationResult({
    required this.accountId,
    required this.creditFacilityId,
    required this.paymentInstrumentId,
  });

  final String accountId;
  final String creditFacilityId;
  final String paymentInstrumentId;
}

/// The two ids [AccountCreationService.createDepositAccount] composes --
/// one row each in `Accounts` and `DepositDetails`, both created inside
/// the same transaction (see that method's own doc).
class DepositCreationResult {
  const DepositCreationResult({required this.accountId, required this.depositDetailsId});

  final String accountId;
  final String depositDetailsId;
}

/// Checkpoint G (docs/20 §13.4/§12.6): the ONLY caller that composes
/// more than one repository call into a single atomic account-creation
/// operation for the Add Account UX. This class does not duplicate or
/// re-implement any repository's own validation -- it only SEQUENCES
/// already-existing, already-tested calls to [AccountRepository],
/// [CreditFacilityRepository], [DepositRepository],
/// [PaymentInstrumentRepository], and [FinancialInstitutionRepository]
/// inside one `AppDatabase.transaction`, so that if any step throws,
/// every write already made by earlier steps in the same call rolls
/// back -- no orphan/half-created account, and (as of this revision) no
/// orphan institution row either, is ever left behind. This is the
/// "small, narrowly scoped application service" the checkpoint's own
/// brief anticipates might be needed for atomic multi-record
/// composition; it is intentionally NOT a broader repository-layer
/// rewrite.
///
/// **Revision note (post-implementation transaction-boundary audit):**
/// every method now takes an optional [institutionName] (never a
/// pre-resolved id) and resolves it via
/// [FinancialInstitutionRepository.findOrCreate] as the FIRST step
/// INSIDE the same `_db.transaction()` as the account/child-record
/// writes that follow it -- including for [createSimpleAccount], which
/// is now always wrapped in a transaction too (previously skipped, since
/// a bare `createClassifiedAccount` call was a single atomic `INSERT`
/// on its own; once institution resolution is also a step in the same
/// call, that call is no longer single-statement and needs the same
/// wrapper). Before this revision, the caller (the Add Account form)
/// resolved the institution via a separate, already-committed call
/// BEFORE invoking this service at all -- so a newly-created (not
/// reused) `FinancialInstitutions` row could survive a subsequent
/// account-creation failure as an orphan, unreferenced row. Moving
/// resolution inside the transaction closes that gap: either the whole
/// call (institution + account + any child rows) commits together, or
/// none of it does.
class AccountCreationService {
  AccountCreationService({
    required AppDatabase db,
    required AccountRepository accountRepository,
    required CreditFacilityRepository creditFacilityRepository,
    required DepositRepository depositRepository,
    required PaymentInstrumentRepository paymentInstrumentRepository,
    required FinancialInstitutionRepository financialInstitutionRepository,
  })  : _db = db,
        _accountRepository = accountRepository,
        _creditFacilityRepository = creditFacilityRepository,
        _depositRepository = depositRepository,
        _paymentInstrumentRepository = paymentInstrumentRepository,
        _financialInstitutionRepository = financialInstitutionRepository;

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  final CreditFacilityRepository _creditFacilityRepository;
  final DepositRepository _depositRepository;
  final PaymentInstrumentRepository _paymentInstrumentRepository;
  final FinancialInstitutionRepository _financialInstitutionRepository;

  /// Resolves [institutionName] (if non-null) to an institution id via
  /// [FinancialInstitutionRepository.findOrCreate] -- callers only ever
  /// call this from INSIDE an already-open `_db.transaction()` (every
  /// method below), so a newly-created institution row is committed
  /// only if the rest of that same transaction also succeeds.
  Future<String?> _resolveInstitution({
    required String profileId,
    required String? institutionName,
  }) async {
    if (institutionName == null || institutionName.trim().isEmpty) return null;
    return _financialInstitutionRepository.findOrCreate(
      profileId: profileId,
      name: institutionName,
    );
  }

  /// Creates a single-record account for any [AccountCreationKind] that
  /// is neither [AccountCreationKind.requiresCreditFacility] nor
  /// [AccountCreationKind.requiresDepositDetails] -- cash, bank,
  /// savings, wallet. Always wrapped in `_db.transaction()`: when
  /// [institutionName] is supplied, this is now a two-step call
  /// (resolve institution, then insert the account), and both must
  /// commit together -- see this class's own revision note.
  Future<String> createSimpleAccount({
    required AccountCreationKind kind,
    required String profileId,
    required String name,
    required String currencyCode,
    Money? openingBalance,
    String? institutionName,
  }) {
    assert(
      !kind.requiresCreditFacility && !kind.requiresDepositDetails,
      'createSimpleAccount only supports single-record kinds -- use '
      'createCreditCardAccount/createDepositAccount for $kind.',
    );
    return _db.transaction(() async {
      final String? institutionId = await _resolveInstitution(
        profileId: profileId,
        institutionName: institutionName,
      );
      return _accountRepository.createClassifiedAccount(
        profileId: profileId,
        name: name,
        type: kind.legacyTypeLabel,
        balanceClass: kind.balanceClass,
        subtype: kind.subtype,
        currencyCode: currencyCode,
        openingBalance: openingBalance,
        institutionId: institutionId,
      );
    });
  }

  /// Creates a [AccountCreationKind.creditCard] account: one liability
  /// `FinancialAccount`, one `CreditFacilityDetails` row, and one
  /// `creditCard` `PaymentInstrument` row, in that order -- optionally
  /// preceded by resolving [institutionName] -- all inside a single
  /// `_db.transaction()` -- docs/20 §12.6's frozen "one step, three
  /// rows, one transaction" contract, now also covering the optional
  /// institution row. If [creditLimit] or any other argument fails
  /// [CreditFacilityRepository.createFacility]'s or
  /// [PaymentInstrumentRepository.createInstrument]'s own validation,
  /// that step's exception propagates out of the transaction, every
  /// write already made in this call (including the `FinancialAccount`
  /// insert and any newly-created institution row) is rolled back, and
  /// no rows from this call exist afterward.
  ///
  /// [owedAmount] is the account's opening balance -- passed straight
  /// through to [AccountRepository.createClassifiedAccount] as the
  /// same non-negative "amount currently owed" magnitude a liability
  /// account already expects; this service never flips its sign.
  Future<CreditCardCreationResult> createCreditCardAccount({
    required String profileId,
    required String name,
    required String currencyCode,
    required Money owedAmount,
    required Money creditLimit,
    String? institutionName,
    CardNetwork? network,
    String? last4,
    int? expiryMonth,
    int? expiryYear,
    int? statementClosingDay,
    int? dueDay,
  }) {
    return _db.transaction(() async {
      final String? institutionId = await _resolveInstitution(
        profileId: profileId,
        institutionName: institutionName,
      );
      final String accountId = await _accountRepository.createClassifiedAccount(
        profileId: profileId,
        name: name,
        type: AccountCreationKind.creditCard.legacyTypeLabel,
        balanceClass: AccountCreationKind.creditCard.balanceClass,
        subtype: AccountCreationKind.creditCard.subtype,
        currencyCode: currencyCode,
        openingBalance: owedAmount,
        institutionId: institutionId,
      );
      final String creditFacilityId = await _creditFacilityRepository.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: creditLimit,
        statementClosingDay: statementClosingDay,
        dueDay: dueDay,
      );
      final String paymentInstrumentId = await _paymentInstrumentRepository.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.creditCard,
        nickname: name,
        network: network,
        last4: last4,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        institutionId: institutionId,
      );
      return CreditCardCreationResult(
        accountId: accountId,
        creditFacilityId: creditFacilityId,
        paymentInstrumentId: paymentInstrumentId,
      );
    });
  }

  /// Creates a [AccountCreationKind.deposit] account: one asset
  /// `FinancialAccount` and one `DepositDetails` row -- optionally
  /// preceded by resolving [institutionName] -- all inside a single
  /// `_db.transaction()`. If [DepositRepository.createDetails] throws
  /// (e.g. a compound [interestMethod] missing [compoundingFrequency] --
  /// see that method's own frozen Checkpoint F validation), the
  /// `FinancialAccount` insert (and any newly-created institution row)
  /// made earlier in this same call is rolled back too -- no orphan row
  /// of any kind is left behind.
  ///
  /// [principal] is the account's opening balance -- a deposit account
  /// carries no second balance anywhere; [DepositDetails] itself has no
  /// balance/amount column of its own (see `tables.dart`'s doc on that
  /// table).
  Future<DepositCreationResult> createDepositAccount({
    required String profileId,
    required String name,
    required String currencyCode,
    required Money principal,
    required DepositType depositType,
    required int termNumber,
    required DepositTermUnit termUnit,
    required DateTime startDateUtc,
    required int interestRateBasisPoints,
    required DepositInterestMethod interestMethod,
    DepositCompoundingFrequency? compoundingFrequency,
    DateTime? explicitMaturityDate,
    bool autoRenew = false,
    String? renewalMode,
    String? interestDestinationAccountId,
    int? installmentAmountMinorUnits,
    DepositInstallmentFrequency? installmentFrequency,
    String? institutionName,
  }) {
    return _db.transaction(() async {
      final String? institutionId = await _resolveInstitution(
        profileId: profileId,
        institutionName: institutionName,
      );
      final String accountId = await _accountRepository.createClassifiedAccount(
        profileId: profileId,
        name: name,
        type: AccountCreationKind.deposit.legacyTypeLabel,
        balanceClass: AccountCreationKind.deposit.balanceClass,
        subtype: AccountCreationKind.deposit.subtype,
        currencyCode: currencyCode,
        openingBalance: principal,
        institutionId: institutionId,
      );
      final String depositDetailsId = await _depositRepository.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: depositType,
        termNumber: termNumber,
        termUnit: termUnit,
        startDateUtc: startDateUtc,
        interestRateBasisPoints: interestRateBasisPoints,
        interestMethod: interestMethod,
        compoundingFrequency: compoundingFrequency,
        explicitMaturityDate: explicitMaturityDate,
        autoRenew: autoRenew,
        renewalMode: renewalMode,
        interestDestinationAccountId: interestDestinationAccountId,
        installmentAmountMinorUnits: installmentAmountMinorUnits,
        installmentFrequency: installmentFrequency,
      );
      return DepositCreationResult(accountId: accountId, depositDetailsId: depositDetailsId);
    });
  }
}
