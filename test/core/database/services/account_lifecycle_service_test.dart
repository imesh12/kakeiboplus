import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/credit_facility_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/services/account_creation_service.dart';
import 'package:ai_financial_coach/core/database/services/account_lifecycle_service.dart';
import 'package:ai_financial_coach/core/database/repositories/financial_institution_repository.dart';
import 'package:ai_financial_coach/core/finance/account_creation_kind.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/deposit_interest_method.dart';
import 'package:ai_financial_coach/core/finance/deposit_term_unit.dart';
import 'package:ai_financial_coach/core/finance/deposit_type.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Account Lifecycle Checkpoint: service-level coverage for
// `AccountLifecycleService` -- the single entry point for closing
// ("deactivating") and reopening ("reactivating") an existing account.
// Mirrors `account_creation_service_test.dart`'s own setup shape exactly
// (same `AccountCreationService` wiring, reused here to create the
// accounts each test closes/reactivates).
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late CreditFacilityRepository facilityRepo;
  late DepositRepository depositRepo;
  late PaymentInstrumentRepository instrumentRepo;
  late FinancialInstitutionRepository institutionRepo;
  late RecurringRuleRepository ruleRepo;
  late AccountCreationService creationService;
  late AccountLifecycleService lifecycleService;
  late String profileId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    facilityRepo = CreditFacilityRepository(db, accountRepo);
    depositRepo = DepositRepository(db, accountRepo);
    instrumentRepo = PaymentInstrumentRepository(db, accountRepo);
    institutionRepo = FinancialInstitutionRepository(db);
    ruleRepo = RecurringRuleRepository(db, accountRepo);
    creationService = AccountCreationService(
      db: db,
      accountRepository: accountRepo,
      creditFacilityRepository: facilityRepo,
      depositRepository: depositRepo,
      paymentInstrumentRepository: instrumentRepo,
      financialInstitutionRepository: institutionRepo,
    );
    lifecycleService = AccountLifecycleService(
      db: db,
      accountRepository: accountRepo,
      paymentInstrumentRepository: instrumentRepo,
      recurringRuleRepository: ruleRepo,
    );

    profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'US',
      currentCountry: 'US',
      homeCurrency: 'USD',
      livingCurrency: 'USD',
      preferredLanguage: 'en',
      timezone: 'America/New_York',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('closeAccount — a plain (cash/bank/wallet/savings) account', () {
    test('sets isActive false and deletedAt, preserves identity/balance/currency/class/subtype',
        () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.bank,
        profileId: profileId,
        name: 'Checking',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(150000, 'USD'),
      );
      final AccountRow before = await accountRepo.requireById(accountId);

      await lifecycleService.closeAccount(accountId: accountId);

      final AccountRow after = await accountRepo.requireById(accountId);
      expect(after.isActive, isFalse);
      expect(after.deletedAt, isNotNull);
      expect(after.id, before.id);
      expect(after.name, before.name);
      expect(after.type, before.type);
      expect(after.currencyCode, before.currencyCode);
      expect(after.openingBalanceMinorUnits, before.openingBalanceMinorUnits);
      expect(after.balanceClassValue, before.balanceClassValue);
      expect(after.subtypeValue, before.subtypeValue);
    });

    test('a closed account no longer appears in watchActiveForProfile', () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.cash,
        profileId: profileId,
        name: 'Wallet cash',
        currencyCode: 'USD',
      );

      await lifecycleService.closeAccount(accountId: accountId);

      final List<AccountRow> active = await accountRepo.watchActiveForProfile(profileId).first;
      expect(active.any((AccountRow a) => a.id == accountId), isFalse);
    });

    test('a closed account still resolves via watchById and watchAllForProfile (discoverable)',
        () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.cash,
        profileId: profileId,
        name: 'Old wallet',
        currencyCode: 'USD',
      );

      await lifecycleService.closeAccount(accountId: accountId);

      final AccountRow? byId = await accountRepo.watchById(accountId).first;
      expect(byId, isNotNull);
      expect(byId!.deletedAt, isNotNull);

      final List<AccountRow> all = await accountRepo.watchAllForProfile(profileId).first;
      expect(all.any((AccountRow a) => a.id == accountId), isTrue);
    });

    test('closing an already-closed account throws AccountAlreadyClosedException and writes nothing',
        () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.cash,
        profileId: profileId,
        name: 'Wallet',
        currencyCode: 'USD',
      );
      await lifecycleService.closeAccount(accountId: accountId);
      final AccountRow closedOnce = await accountRepo.requireById(accountId);

      await expectLater(
        lifecycleService.closeAccount(accountId: accountId),
        throwsA(isA<AccountAlreadyClosedException>()),
      );

      final AccountRow stillClosed = await accountRepo.requireById(accountId);
      expect(stillClosed.deletedAt, closedOnce.deletedAt);
      expect(stillClosed.updatedAt, closedOnce.updatedAt);
    });
  });

  group('reactivateAccount — a plain account', () {
    test('clears deletedAt/restores isActive, preserves identity/balance/currency/class/subtype/history',
        () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.bank,
        profileId: profileId,
        name: 'Checking',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(75000, 'USD'),
      );
      final AccountRow before = await accountRepo.requireById(accountId);
      await lifecycleService.closeAccount(accountId: accountId);

      await lifecycleService.reactivateAccount(accountId: accountId);

      final AccountRow after = await accountRepo.requireById(accountId);
      expect(after.isActive, isTrue);
      expect(after.deletedAt, isNull);
      expect(after.id, before.id);
      expect(after.name, before.name);
      expect(after.currencyCode, before.currencyCode);
      expect(after.openingBalanceMinorUnits, before.openingBalanceMinorUnits);
      expect(after.balanceClassValue, before.balanceClassValue);
      expect(after.subtypeValue, before.subtypeValue);
    });

    test('a reactivated account reappears in watchActiveForProfile — never a replacement id',
        () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.cash,
        profileId: profileId,
        name: 'Wallet',
        currencyCode: 'USD',
      );
      await lifecycleService.closeAccount(accountId: accountId);

      await lifecycleService.reactivateAccount(accountId: accountId);

      final List<AccountRow> active = await accountRepo.watchActiveForProfile(profileId).first;
      expect(active.where((AccountRow a) => a.id == accountId).length, 1);
      expect(active.length, 1);
    });

    test('reactivating an already-active account throws AccountNotClosedException', () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.cash,
        profileId: profileId,
        name: 'Wallet',
        currencyCode: 'USD',
      );

      await expectLater(
        lifecycleService.reactivateAccount(accountId: accountId),
        throwsA(isA<AccountNotClosedException>()),
      );
    });
  });

  group('closeAccount / reactivateAccount — credit card', () {
    test('closing archives its PaymentInstrument(s); CreditFacilityDetails is untouched', () async {
      final CreditCardCreationResult result = await creationService.createCreditCardAccount(
        profileId: profileId,
        name: 'Visa',
        currencyCode: 'USD',
        owedAmount: Money.fromMinorUnits(20000, 'USD'),
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
      );

      await lifecycleService.closeAccount(accountId: result.accountId);

      final AccountRow account = await accountRepo.requireById(result.accountId);
      expect(account.deletedAt, isNotNull);
      expect(account.balanceClassValue, BalanceClass.liability);
      expect(account.subtypeValue, FinancialAccountSubtype.creditCard);

      final List<PaymentInstrumentRow> active =
          await instrumentRepo.watchActiveForAccount(result.accountId).first;
      expect(active, isEmpty);
      final PaymentInstrumentRow? archived =
          await instrumentRepo.findByIdIncludingDeleted(result.paymentInstrumentId);
      expect(archived, isNotNull);
      expect(archived!.deletedAt, isNotNull);
      // CreditFacilityDetails is never touched by closing an account --
      // it stays resolvable, still linked by `accountId`, exactly as it
      // was before.
      final CreditFacilityDetailsRow facility =
          await facilityRepo.requireActiveForAccount(result.accountId);
      expect(facility.id, result.creditFacilityId);
      expect(facility.creditLimitMinorUnits, 500000);
    });

    test('reactivating restores exactly the instrument(s) it archived -- no duplicate rows',
        () async {
      final CreditCardCreationResult result = await creationService.createCreditCardAccount(
        profileId: profileId,
        name: 'Visa',
        currencyCode: 'USD',
        owedAmount: Money.fromMinorUnits(0, 'USD'),
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
      );
      await lifecycleService.closeAccount(accountId: result.accountId);

      await lifecycleService.reactivateAccount(accountId: result.accountId);

      final List<PaymentInstrumentRow> active =
          await instrumentRepo.watchActiveForAccount(result.accountId).first;
      expect(active.length, 1);
      expect(active.single.id, result.paymentInstrumentId);
      final List<PaymentInstrumentRow> allForAccount =
          await instrumentRepo.allForAccountOnce(result.accountId);
      // Never duplicated by a close+reactivate cycle.
      expect(allForAccount.length, 1);

      final CreditFacilityDetailsRow facility =
          await facilityRepo.requireActiveForAccount(result.accountId);
      expect(facility.id, result.creditFacilityId);
    });

    test('a close+reactivate cycle twice never duplicates the instrument row', () async {
      final CreditCardCreationResult result = await creationService.createCreditCardAccount(
        profileId: profileId,
        name: 'Visa',
        currencyCode: 'USD',
        owedAmount: Money.fromMinorUnits(0, 'USD'),
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
      );

      await lifecycleService.closeAccount(accountId: result.accountId);
      await lifecycleService.reactivateAccount(accountId: result.accountId);
      await lifecycleService.closeAccount(accountId: result.accountId);
      await lifecycleService.reactivateAccount(accountId: result.accountId);

      final List<PaymentInstrumentRow> allForAccount =
          await instrumentRepo.allForAccountOnce(result.accountId);
      expect(allForAccount.length, 1);
      expect(allForAccount.single.deletedAt, isNull);
    });
  });

  group('closeAccount / reactivateAccount — deposit', () {
    test('closing preserves DepositDetails and the account\'s balance/history untouched', () async {
      final DepositCreationResult result = await creationService.createDepositAccount(
        profileId: profileId,
        name: 'Fixed deposit',
        currencyCode: 'USD',
        principal: Money.fromMinorUnits(1000000, 'USD'),
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 250,
        interestMethod: DepositInterestMethod.simple,
      );

      await lifecycleService.closeAccount(accountId: result.accountId);

      final AccountRow account = await accountRepo.requireById(result.accountId);
      expect(account.deletedAt, isNotNull);
      expect(account.openingBalanceMinorUnits, 1000000);
      expect(account.subtypeValue, FinancialAccountSubtype.deposit);

      final DepositDetailsRow details = await depositRepo.requireActiveForAccount(result.accountId);
      expect(details.id, result.depositDetailsId);
      expect(details.deletedAt, isNull);
    });

    test('reactivating a closed deposit account never duplicates DepositDetails', () async {
      final DepositCreationResult result = await creationService.createDepositAccount(
        profileId: profileId,
        name: 'Fixed deposit',
        currencyCode: 'USD',
        principal: Money.fromMinorUnits(1000000, 'USD'),
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 250,
        interestMethod: DepositInterestMethod.simple,
      );

      await lifecycleService.closeAccount(accountId: result.accountId);
      await lifecycleService.reactivateAccount(accountId: result.accountId);

      final AccountRow account = await accountRepo.requireById(result.accountId);
      expect(account.isActive, isTrue);
      final DepositDetailsRow details = await depositRepo.requireActiveForAccount(result.accountId);
      expect(details.id, result.depositDetailsId);
    });
  });

  group('closeAccount — recurring rule dependency', () {
    test('blocks closing an account that is the SOURCE of an active recurring rule', () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.bank,
        profileId: profileId,
        name: 'Checking',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(50000, 'USD'),
        accountId: accountId,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(2026, 1, 1),
      );

      await expectLater(
        lifecycleService.closeAccount(accountId: accountId),
        throwsA(isA<AccountHasActiveRecurringRulesException>()),
      );

      final AccountRow stillActive = await accountRepo.requireById(accountId);
      expect(stillActive.isActive, isTrue);
      expect(stillActive.deletedAt, isNull);
    });

    test('blocks closing an account that is the DESTINATION of an active transfer rule', () async {
      final String sourceId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.bank,
        profileId: profileId,
        name: 'Checking',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      final String destinationId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.savings,
        profileId: profileId,
        name: 'Savings',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(0, 'USD'),
      );
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.transfer,
        name: 'Monthly savings',
        amount: Money.fromMinorUnits(20000, 'USD'),
        accountId: sourceId,
        destinationAccountId: destinationId,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(2026, 1, 1),
      );

      await expectLater(
        lifecycleService.closeAccount(accountId: destinationId),
        throwsA(isA<AccountHasActiveRecurringRulesException>()),
      );
    });

    test('does NOT block closing once the referencing rule is itself deleted first', () async {
      final String accountId = await creationService.createSimpleAccount(
        kind: AccountCreationKind.bank,
        profileId: profileId,
        name: 'Checking',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      final String ruleId = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(50000, 'USD'),
        accountId: accountId,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(2026, 1, 1),
      );
      await ruleRepo.softDelete(ruleId);

      await lifecycleService.closeAccount(accountId: accountId);

      final AccountRow closed = await accountRepo.requireById(accountId);
      expect(closed.deletedAt, isNotNull);
    });
  });
}
