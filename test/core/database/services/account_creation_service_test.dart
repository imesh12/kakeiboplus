import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/credit_facility_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_validation_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/financial_institution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/services/account_creation_service.dart';
import 'package:ai_financial_coach/core/finance/account_creation_kind.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/deposit_interest_method.dart';
import 'package:ai_financial_coach/core/finance/deposit_term_unit.dart';
import 'package:ai_financial_coach/core/finance/deposit_type.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint G (Add Account UX): service-level coverage for
// `AccountCreationService` -- the ONLY caller that composes multiple
// repository calls into one atomic account-creation operation. This is
// the checkpoint's own "add tests for rollback/failure behavior if a
// transactional creation service is introduced" requirement: every
// failure-path test here confirms that a thrown exception partway
// through a multi-record creation leaves NO row behind at all (not the
// `Accounts` row, not the child row), because
// `AppDatabase.transaction` rolls back the whole call.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late CreditFacilityRepository facilityRepo;
  late DepositRepository depositRepo;
  late PaymentInstrumentRepository instrumentRepo;
  late FinancialInstitutionRepository institutionRepo;
  late AccountCreationService service;
  late String profileId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    facilityRepo = CreditFacilityRepository(db, accountRepo);
    depositRepo = DepositRepository(db, accountRepo);
    instrumentRepo = PaymentInstrumentRepository(db, accountRepo);
    institutionRepo = FinancialInstitutionRepository(db);
    service = AccountCreationService(
      db: db,
      accountRepository: accountRepo,
      creditFacilityRepository: facilityRepo,
      depositRepository: depositRepo,
      paymentInstrumentRepository: instrumentRepo,
      financialInstitutionRepository: institutionRepo,
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

  group('createSimpleAccount', () {
    for (final AccountCreationKind kind in <AccountCreationKind>[
      AccountCreationKind.cash,
      AccountCreationKind.bank,
      AccountCreationKind.savings,
      AccountCreationKind.wallet,
    ]) {
      test('${kind.name}: creates exactly one asset FinancialAccount with the right subtype', () async {
        final String accountId = await service.createSimpleAccount(
          kind: kind,
          profileId: profileId,
          name: '${kind.name} account',
          currencyCode: 'USD',
          openingBalance: Money.fromMinorUnits(50000, 'USD'),
        );

        final AccountRow account = await accountRepo.requireById(accountId);
        expect(account.balanceClassValue, BalanceClass.asset);
        expect(account.subtypeValue, kind.subtype);
        expect(account.type, kind.legacyTypeLabel);
        expect(account.openingBalanceMinorUnits, 50000);
        expect(account.currencyCode, 'USD');
      });
    }

    test(
        'savings persists its own FinancialAccountSubtype.savings, distinct from bank '
        '(Checkpoint K -- docs/20 §13.5 open question 1, now resolved)', () async {
      final String bankId = await service.createSimpleAccount(
        kind: AccountCreationKind.bank,
        profileId: profileId,
        name: 'Everyday',
        currencyCode: 'USD',
      );
      final String savingsId = await service.createSimpleAccount(
        kind: AccountCreationKind.savings,
        profileId: profileId,
        name: 'Nest egg',
        currencyCode: 'USD',
      );
      final AccountRow bank = await accountRepo.requireById(bankId);
      final AccountRow savings = await accountRepo.requireById(savingsId);
      expect(bank.subtypeValue, FinancialAccountSubtype.bank);
      expect(savings.subtypeValue, FinancialAccountSubtype.savings);
      expect(savings.subtypeValue, isNot(bank.subtypeValue));
      // Both remain plain assets -- savings is not a distinct
      // BalanceClass, just its own subtype.
      expect(savings.balanceClassValue, BalanceClass.asset);
      // Their presentation-only `type` strings also stay distinct, as
      // they always have.
      expect(bank.type, isNot(savings.type));
    });

    test('a null openingBalance defaults to zero, never a negative/authoritative-double value', () async {
      final String accountId = await service.createSimpleAccount(
        kind: AccountCreationKind.cash,
        profileId: profileId,
        name: 'Wallet cash',
        currencyCode: 'JPY',
      );
      final AccountRow account = await accountRepo.requireById(accountId);
      expect(account.openingBalanceMinorUnits, 0);
    });
  });

  group('createCreditCardAccount', () {
    test(
      'success: creates one liability FinancialAccount, one CreditFacilityDetails row, and one '
      'creditCard PaymentInstrument, all pointing at each other',
      () async {
        final CreditCardCreationResult result = await service.createCreditCardAccount(
          profileId: profileId,
          name: 'Everyday Visa',
          currencyCode: 'USD',
          owedAmount: Money.fromMinorUnits(15000, 'USD'),
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
        );

        final AccountRow account = await accountRepo.requireById(result.accountId);
        expect(account.balanceClassValue, BalanceClass.liability);
        expect(account.subtypeValue, FinancialAccountSubtype.creditCard);
        // The opening "amount owed" is stored as the same non-negative
        // magnitude the user typed -- no sign flip anywhere in this path.
        expect(account.openingBalanceMinorUnits, 15000);

        final CreditFacilityDetailsRow facility = await facilityRepo.requireActiveForAccount(
          result.accountId,
        );
        expect(facility.id, result.creditFacilityId);
        expect(facility.accountId, result.accountId);
        expect(facility.creditLimitMinorUnits, 500000);

        final PaymentInstrumentRow instrument = await instrumentRepo.requireActiveById(
          result.paymentInstrumentId,
        );
        expect(instrument.accountId, result.accountId);
        expect(instrument.instrumentType, 'creditCard');
      },
    );

    test(
      'failure in the facility step (invalid credit limit) rolls back the whole transaction -- '
      'no orphan liability FinancialAccount is left behind',
      () async {
        await expectLater(
          service.createCreditCardAccount(
            profileId: profileId,
            name: 'Should not exist',
            currencyCode: 'USD',
            owedAmount: Money.fromMinorUnits(0, 'USD'),
            // Negative credit limit -- `CreditFacilityRepository
            // .createFacility` throws `ArgumentError` for this (zero is
            // allowed, negative is not).
            creditLimit: Money.fromMinorUnits(-100, 'USD'),
          ),
          throwsA(isA<ArgumentError>()),
        );

        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
        final List<CreditFacilityDetailsRow> facilities =
            await db.select(db.creditFacilityDetails).get();
        expect(facilities, isEmpty);
      },
    );

    test(
      'failure in the payment-instrument step (invalid last4) rolls back the whole transaction '
      '-- no orphan FinancialAccount or CreditFacilityDetails row is left behind',
      () async {
        await expectLater(
          service.createCreditCardAccount(
            profileId: profileId,
            name: 'Should not exist either',
            currencyCode: 'USD',
            owedAmount: Money.fromMinorUnits(0, 'USD'),
            creditLimit: Money.fromMinorUnits(100000, 'USD'),
            // `PaymentInstrumentRepository._validateLast4` requires
            // exactly 4 digits.
            last4: '12',
          ),
          throwsA(isA<ArgumentError>()),
        );

        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
        final List<CreditFacilityDetailsRow> facilities =
            await db.select(db.creditFacilityDetails).get();
        expect(facilities, isEmpty);
        final List<PaymentInstrumentRow> instruments = await db.select(db.paymentInstruments).get();
        expect(instruments, isEmpty);
      },
    );
  });

  group('createDepositAccount', () {
    test(
      'success: creates one asset FinancialAccount and one DepositDetails row; the principal '
      'exists only as the FinancialAccount balance, never a second stored balance',
      () async {
        final DepositCreationResult result = await service.createDepositAccount(
          profileId: profileId,
          name: 'One-year fixed',
          currencyCode: 'USD',
          principal: Money.fromMinorUnits(1000000, 'USD'),
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2027, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
        );

        final AccountRow account = await accountRepo.requireById(result.accountId);
        expect(account.balanceClassValue, BalanceClass.asset);
        expect(account.subtypeValue, FinancialAccountSubtype.deposit);
        expect(account.openingBalanceMinorUnits, 1000000);

        final DepositDetailsRow details = await depositRepo.requireActiveForAccount(
          result.accountId,
        );
        expect(details.id, result.depositDetailsId);
        expect(details.accountId, result.accountId);
        expect(details.interestRateBasisPoints, 500);
      },
    );

    test(
      'failure in the DepositDetails step (compound method missing compoundingFrequency) rolls '
      'back the whole transaction -- no orphan asset FinancialAccount is left behind',
      () async {
        await expectLater(
          service.createDepositAccount(
            profileId: profileId,
            name: 'Should not exist',
            currencyCode: 'USD',
            principal: Money.fromMinorUnits(1000000, 'USD'),
            depositType: DepositType.fixed,
            termNumber: 12,
            termUnit: DepositTermUnit.months,
            startDateUtc: DateTime.utc(2027, 1, 1),
            interestRateBasisPoints: 500,
            interestMethod: DepositInterestMethod.compound,
            // Deliberately omitted: compoundingFrequency.
          ),
          throwsA(isA<DepositValidationException>()),
        );

        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
        final List<DepositDetailsRow> details = await db.select(db.depositDetails).get();
        expect(details, isEmpty);
      },
    );

    test(
      'failure in the DepositDetails step (termNumber < 1) rolls back the whole transaction -- '
      'no orphan asset FinancialAccount is left behind',
      () async {
        await expectLater(
          service.createDepositAccount(
            profileId: profileId,
            name: 'Should not exist either',
            currencyCode: 'USD',
            principal: Money.fromMinorUnits(1000000, 'USD'),
            depositType: DepositType.fixed,
            termNumber: 0,
            termUnit: DepositTermUnit.months,
            startDateUtc: DateTime.utc(2027, 1, 1),
            interestRateBasisPoints: 500,
            interestMethod: DepositInterestMethod.simple,
          ),
          throwsA(isA<ArgumentError>()),
        );

        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
      },
    );
  });

  // Checkpoint G revision (Task 4 of the follow-up verification/coverage
  // increment): institution resolution used to happen in the caller
  // (the Add Account form), as a separate call that committed BEFORE
  // `AccountCreationService` ever ran -- so a brand-new
  // `FinancialInstitutions` row could survive a later account-creation
  // failure as an orphan. `_resolveInstitution` now runs as the first
  // step INSIDE the same `_db.transaction()` as the rest of each
  // method, so these two tests prove the gap is closed: a successful
  // call commits the institution together with the account, and a
  // failed call leaves no institution row behind either, not just no
  // account/child row.
  group('institution atomicity (Checkpoint G revision)', () {
    test(
      'createSimpleAccount success: a new institutionName is created and linked to the '
      'new account, both visible after commit',
      () async {
        final String accountId = await service.createSimpleAccount(
          kind: AccountCreationKind.bank,
          profileId: profileId,
          name: 'Everyday',
          currencyCode: 'USD',
          institutionName: 'First Federal',
        );

        final AccountRow account = await accountRepo.requireById(accountId);
        expect(account.institutionId, isNotNull);

        final List<FinancialInstitutionRow> institutions =
            await db.select(db.financialInstitutions).get();
        expect(institutions, hasLength(1));
        expect(institutions.single.id, account.institutionId);
        expect(institutions.single.name, 'First Federal');
      },
    );

    test(
      'createCreditCardAccount failure (invalid credit limit): a brand-new institutionName '
      'supplied for this call is rolled back too -- no orphan FinancialInstitutions row, in '
      'addition to no orphan FinancialAccount/CreditFacilityDetails row',
      () async {
        await expectLater(
          service.createCreditCardAccount(
            profileId: profileId,
            name: 'Should not exist',
            currencyCode: 'USD',
            owedAmount: Money.fromMinorUnits(0, 'USD'),
            creditLimit: Money.fromMinorUnits(-100, 'USD'),
            institutionName: 'Brand New Bank',
          ),
          throwsA(isA<ArgumentError>()),
        );

        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
        final List<CreditFacilityDetailsRow> facilities =
            await db.select(db.creditFacilityDetails).get();
        expect(facilities, isEmpty);
        // The key assertion for this gap: the institution row this
        // call would have created must not survive the rollback.
        final List<FinancialInstitutionRow> institutions =
            await db.select(db.financialInstitutions).get();
        expect(institutions, isEmpty);
      },
    );

    test(
      'createDepositAccount failure (compound method missing compoundingFrequency): a '
      'brand-new institutionName supplied for this call is rolled back too -- no orphan '
      'FinancialInstitutions row, in addition to no orphan FinancialAccount row',
      () async {
        await expectLater(
          service.createDepositAccount(
            profileId: profileId,
            name: 'Should not exist',
            currencyCode: 'USD',
            principal: Money.fromMinorUnits(1000000, 'USD'),
            depositType: DepositType.fixed,
            termNumber: 12,
            termUnit: DepositTermUnit.months,
            startDateUtc: DateTime.utc(2027, 1, 1),
            interestRateBasisPoints: 500,
            interestMethod: DepositInterestMethod.compound,
            institutionName: 'Another Brand New Bank',
          ),
          throwsA(isA<DepositValidationException>()),
        );

        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
        final List<FinancialInstitutionRow> institutions =
            await db.select(db.financialInstitutions).get();
        expect(institutions, isEmpty);
      },
    );

    test(
      'createSimpleAccount reuses an existing institution by exact case-insensitive '
      'trimmed-name match rather than creating a duplicate row, even when called from '
      'inside the service\'s own transaction',
      () async {
        final String firstAccountId = await service.createSimpleAccount(
          kind: AccountCreationKind.bank,
          profileId: profileId,
          name: 'Checking one',
          currencyCode: 'USD',
          institutionName: 'Chase',
        );
        final String secondAccountId = await service.createSimpleAccount(
          kind: AccountCreationKind.savings,
          profileId: profileId,
          name: 'Checking two',
          currencyCode: 'USD',
          institutionName: '  chase  ',
        );

        final AccountRow first = await accountRepo.requireById(firstAccountId);
        final AccountRow second = await accountRepo.requireById(secondAccountId);
        expect(first.institutionId, isNotNull);
        expect(second.institutionId, first.institutionId);

        final List<FinancialInstitutionRow> institutions =
            await db.select(db.financialInstitutions).get();
        expect(institutions, hasLength(1));
      },
    );
  });
}
