import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/credit_facility_not_found_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/credit_facility_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/credit_facility_validation_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint E: CreditFacilityDetails foundation. Today's production Add
// Account UX cannot create a liability/creditCard account yet
// (Checkpoints B/C/D only ever produce asset-classified rows through
// the app), so every test below seeds a liability/creditCard account
// directly through this DB fixture, exactly as Checkpoint D's own
// precedent for a `creditCard` PaymentInstrument already established --
// rather than weakening `CreditFacilityRepository`'s own validation to
// accommodate UI that doesn't exist yet.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late CreditFacilityRepository facilityRepo;
  late String profileId;
  const Uuid uuid = Uuid();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    facilityRepo = CreditFacilityRepository(db, accountRepo);

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

  /// Seeds a liability account with subtype `creditCard` directly
  /// through the DB, bypassing `AccountRepository.createAccount` (which
  /// today only ever produces asset-classified rows).
  Future<String> seedCreditCardAccount({
    String currencyCode = 'USD',
    int openingBalanceMinorUnits = 0,
    String? ownerProfileId,
  }) async {
    final String id = uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            profileId: ownerProfileId ?? profileId,
            name: 'Test Credit Card',
            type: 'card',
            currencyCode: currencyCode,
            openingBalanceMinorUnits: Value<int>(openingBalanceMinorUnits),
            balanceClass: const Value<String>('liability'),
            subtype: const Value<String>('creditCard'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Seeds a liability account with some OTHER subtype, for the
  /// wrong-subtype rejection test -- a hypothetical shape (no production
  /// path creates this today) used only to prove the validation rejects
  /// it, matching how Checkpoint D's own tests seed a bespoke fixture
  /// row purely to exercise a rejection path.
  Future<String> seedLiabilityWithWrongSubtype({String subtype = 'legacyUnknownNeedsReview'}) async {
    final String id = uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            profileId: profileId,
            name: 'Some Other Liability',
            type: 'card',
            currencyCode: 'USD',
            balanceClass: const Value<String>('liability'),
            subtype: Value<String>(subtype),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  group('createFacility -- account eligibility', () {
    test('1. valid creation for a liability + creditCard account', () async {
      final String accountId = await seedCreditCardAccount();
      final String id = await facilityRepo.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
      );
      expect(id, isNotEmpty);
      final CreditFacilityDetailsRow row = await facilityRepo.requireActiveForAccount(accountId);
      expect(row.accountId, accountId);
      expect(row.creditLimitMinorUnits, 500000);
    });

    test('2. rejected for an asset account', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
        ),
        throwsA(isA<CreditFacilityValidationException>()),
      );
    });

    test('3. rejected for a liability account with the wrong subtype', () async {
      final String accountId = await seedLiabilityWithWrongSubtype();
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
        ),
        throwsA(isA<CreditFacilityValidationException>()),
      );
    });
  });

  group('createFacility -- credit limit validation', () {
    test('4a. a positive credit limit is accepted', () async {
      final String accountId = await seedCreditCardAccount();
      await facilityRepo.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: Money.fromMinorUnits(200000, 'USD'),
      );
      final CreditFacilityDetailsRow row = await facilityRepo.requireActiveForAccount(accountId);
      expect(row.creditLimitMinorUnits, 200000);
    });

    test('4b. a zero credit limit is accepted -- not the same as invalid', () async {
      final String accountId = await seedCreditCardAccount();
      await facilityRepo.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: Money.zero('USD'),
      );
      final CreditFacilityDetailsRow row = await facilityRepo.requireActiveForAccount(accountId);
      expect(row.creditLimitMinorUnits, 0);
    });

    test('4c. a negative credit limit is rejected', () async {
      final String accountId = await seedCreditCardAccount();
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(-100, 'USD'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('4d. a credit limit in a different currency than the account is rejected', () async {
      final String accountId = await seedCreditCardAccount(currencyCode: 'USD');
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('4e. statementClosingDay/dueDay out of range are rejected independently', () async {
      final String accountId = await seedCreditCardAccount();
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
          statementClosingDay: 32,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
          dueDay: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      // A valid, independent pair succeeds.
      await facilityRepo.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
        statementClosingDay: 15,
      );
      final CreditFacilityDetailsRow row = await facilityRepo.requireActiveForAccount(accountId);
      expect(row.statementClosingDay, 15);
      expect(row.dueDay, isNull);
    });
  });

  group('createFacility -- one facility per account', () {
    test('5. a second facility for the same account is rejected', () async {
      final String accountId = await seedCreditCardAccount();
      await facilityRepo.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
      );
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(100000, 'USD'),
        ),
        throwsA(isA<CreditFacilityValidationException>()),
      );
    });
  });

  group('createFacility -- ownership rules', () {
    test('6a. an account belonging to a different profile is rejected', () async {
      const String otherProfileId = 'other-profile-fixture';
      final DateTime now = DateTime.now().toUtc();
      await db.into(db.profiles).insert(
            ProfilesCompanion.insert(
              id: otherProfileId,
              displayName: 'Other User',
              homeCountry: 'US',
              currentCountry: 'US',
              homeCurrency: 'USD',
              livingCurrency: 'USD',
              preferredLanguage: 'en',
              timezone: 'America/New_York',
              dateFormat: 'yyyy-MM-dd',
              numberFormat: '#,##0.##',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final String accountId = await seedCreditCardAccount(ownerProfileId: otherProfileId);
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
        ),
        throwsA(isA<CreditFacilityValidationException>()),
      );
    });

    test('6b. a linkedPaymentAccountId belonging to a different profile is rejected', () async {
      const String otherProfileId = 'other-profile-fixture-2';
      final DateTime now = DateTime.now().toUtc();
      await db.into(db.profiles).insert(
            ProfilesCompanion.insert(
              id: otherProfileId,
              displayName: 'Other User',
              homeCountry: 'US',
              currentCountry: 'US',
              homeCurrency: 'USD',
              livingCurrency: 'USD',
              preferredLanguage: 'en',
              timezone: 'America/New_York',
              dateFormat: 'yyyy-MM-dd',
              numberFormat: '#,##0.##',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final String accountId = await seedCreditCardAccount();
      final String otherPersonsCheckingId = await accountRepo.createAccount(
        profileId: otherProfileId,
        name: 'Their Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      expect(
        () => facilityRepo.createFacility(
          profileId: profileId,
          accountId: accountId,
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
          linkedPaymentAccountId: otherPersonsCheckingId,
        ),
        throwsA(isA<CreditFacilityValidationException>()),
      );
    });

    test('6c. a linkedPaymentAccountId in the same profile is accepted', () async {
      final String accountId = await seedCreditCardAccount();
      final String checkingId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      await facilityRepo.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
        linkedPaymentAccountId: checkingId,
      );
      final CreditFacilityDetailsRow row = await facilityRepo.requireActiveForAccount(accountId);
      expect(row.linkedPaymentAccountId, checkingId);
    });
  });

  group('requireActiveForAccount', () {
    test('throws CreditFacilityNotFoundException when none exists', () async {
      final String accountId = await seedCreditCardAccount();
      expect(
        () => facilityRepo.requireActiveForAccount(accountId),
        throwsA(isA<CreditFacilityNotFoundException>()),
      );
    });
  });

  group('18. availableCredit -- exact derivation, never persisted', () {
    test('creditLimit - amountOwed, exact minor units', () {
      final Money result = CreditFacilityRepository.availableCredit(
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
        amountOwed: Money.fromMinorUnits(120000, 'USD'),
      );
      expect(result, Money.fromMinorUnits(380000, 'USD'));
    });

    test('fully paid off (amountOwed zero) -- available credit equals the whole limit', () {
      final Money result = CreditFacilityRepository.availableCredit(
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
        amountOwed: Money.zero('USD'),
      );
      expect(result, Money.fromMinorUnits(500000, 'USD'));
    });

    test('fully drawn (amountOwed equals limit) -- available credit is exactly zero', () {
      final Money result = CreditFacilityRepository.availableCredit(
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
        amountOwed: Money.fromMinorUnits(500000, 'USD'),
      );
      expect(result, Money.zero('USD'));
    });

    test('a mismatched currency between the two Money values throws CurrencyMismatchException', () {
      expect(
        () => CreditFacilityRepository.availableCredit(
          creditLimit: Money.fromMinorUnits(500000, 'USD'),
          amountOwed: Money.fromMinorUnits(1000, 'JPY'),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });
  });
}
