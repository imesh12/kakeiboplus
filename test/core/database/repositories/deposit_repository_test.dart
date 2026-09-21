import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_not_found_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_validation_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/finance/deposit_calculator.dart';
import 'package:ai_financial_coach/core/finance/deposit_compounding_frequency.dart';
import 'package:ai_financial_coach/core/finance/deposit_installment_frequency.dart';
import 'package:ai_financial_coach/core/finance/deposit_interest_method.dart';
import 'package:ai_financial_coach/core/finance/deposit_term_unit.dart';
import 'package:ai_financial_coach/core/finance/deposit_type.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint F: DepositDetails foundation. Today's production Add Account
// UX cannot create a `subtype: deposit` account yet (Checkpoints B/C/D/E
// only ever produce asset-classified rows with a different subtype
// through the app), so every test below that needs a deposit account
// seeds it directly through this DB fixture -- the same precedent
// Checkpoint E's own `CreditFacilityRepository` tests already established
// for a liability/creditCard account.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late DepositRepository depositRepo;
  late String profileId;
  const Uuid uuid = Uuid();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    depositRepo = DepositRepository(db, accountRepo);

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

  /// Seeds an asset account with subtype `deposit` directly through the
  /// DB, bypassing `AccountRepository.createAccount` (which today only
  /// ever produces a legacy-classified subtype, never `deposit`).
  Future<String> seedDepositAccount({
    String currencyCode = 'USD',
    int openingBalanceMinorUnits = 0,
    String? ownerProfileId,
    bool active = true,
  }) async {
    final String id = uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            profileId: ownerProfileId ?? profileId,
            name: 'Test Deposit',
            type: 'bank',
            currencyCode: currencyCode,
            openingBalanceMinorUnits: Value<int>(openingBalanceMinorUnits),
            balanceClass: const Value<String>('asset'),
            subtype: const Value<String>('deposit'),
            isActive: Value<bool>(active),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Seeds an asset account with some OTHER subtype, for the
  /// wrong-subtype rejection test.
  Future<String> seedAssetWithWrongSubtype({String subtype = 'legacyUnknownNeedsReview'}) async {
    final String id = uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            profileId: profileId,
            name: 'Some Other Asset',
            type: 'bank',
            currencyCode: 'USD',
            balanceClass: const Value<String>('asset'),
            subtype: Value<String>(subtype),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  group('createDetails -- account eligibility', () {
    test('1. valid creation for an asset + deposit account', () async {
      final String accountId = await seedDepositAccount();
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
      );
      expect(id, isNotEmpty);
      final DepositDetailsRow row = await depositRepo.requireActiveForAccount(accountId);
      expect(row.accountId, accountId);
      expect(row.maturityDate, DateTime.utc(2027, 1, 1));
    });

    test('2. rejected for a liability account', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Some Liability',
        type: 'bank',
        currencyCode: 'USD',
      );
      // Force it to liability directly -- createAccount only ever
      // produces asset rows.
      await (db.update(db.accounts)..where((tbl) => tbl.id.equals(accountId)))
          .write(const AccountsCompanion(balanceClass: Value<String>('liability')));
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });

    test('3. rejected for an asset account with the wrong subtype', () async {
      final String accountId = await seedAssetWithWrongSubtype();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });

    test('6. rejected for an inactive (soft-deleted) account', () async {
      final String accountId = await seedDepositAccount();
      await (db.update(db.accounts)..where((tbl) => tbl.id.equals(accountId)))
          .write(AccountsCompanion(deletedAt: Value<DateTime?>(DateTime.now().toUtc())));
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });

    test('6b. rejected for an account with isActive: false', () async {
      final String accountId = await seedDepositAccount(active: false);
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });
  });

  group('createDetails -- term/rate argument-shape validation', () {
    test('rejects termNumber < 1', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 0,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative interestRateBasisPoints', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: -1,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsArgumentError,
      );
    });

    test('allows an interestRateBasisPoints of exactly zero', () async {
      final String accountId = await seedDepositAccount();
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 0,
        interestMethod: DepositInterestMethod.simple,
      );
      expect(id, isNotEmpty);
    });
  });

  group('createDetails -- 16: explicit maturityDate vs term consistency', () {
    test('accepts an explicitMaturityDate that agrees with the computed one', () async {
      final String accountId = await seedDepositAccount();
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 1,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 31),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
        explicitMaturityDate: DateTime.utc(2026, 2, 28), // Jan 31 + 1 month, clamped
      );
      expect(id, isNotEmpty);
    });

    test('rejects an explicitMaturityDate that disagrees with the computed one', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 1,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 31),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
          explicitMaturityDate: DateTime.utc(2026, 3, 1), // wrong -- does not match Feb 28
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });
  });

  group('createDetails -- interestMethod / compoundingFrequency gating', () {
    test('rejects compound without a compoundingFrequency', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.compound,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });

    test('rejects simple with a compoundingFrequency supplied', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
          compoundingFrequency: DepositCompoundingFrequency.monthly,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });

    test('accepts compound with a compoundingFrequency supplied', () async {
      final String accountId = await seedDepositAccount();
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.compound,
        compoundingFrequency: DepositCompoundingFrequency.monthly,
      );
      expect(id, isNotEmpty);
    });
  });

  group('createDetails -- depositType.recurring installment gating', () {
    test('rejects installmentAmountMinorUnits for a non-recurring depositType', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
          installmentAmountMinorUnits: 10000,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });

    test('accepts installment fields for depositType.recurring', () async {
      final String accountId = await seedDepositAccount();
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.recurring,
        termNumber: 24,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
        installmentAmountMinorUnits: 1000000,
        installmentFrequency: DepositInstallmentFrequency.monthly,
      );
      expect(id, isNotEmpty);
    });

    test('recurring depositType does not REQUIRE installment fields', () async {
      final String accountId = await seedDepositAccount();
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.recurring,
        termNumber: 24,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
      );
      expect(id, isNotEmpty);
    });

    test('rejects a non-positive installmentAmountMinorUnits', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.recurring,
          termNumber: 24,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
          installmentAmountMinorUnits: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('createDetails -- 4: one deposit per account', () {
    test('4. rejects a second DepositDetails row for the same account', () async {
      final String accountId = await seedDepositAccount();
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
      );
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 6,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 6, 1),
          interestRateBasisPoints: 400,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });
  });

  group('createDetails -- 5: profile ownership rules', () {
    test('rejects an account belonging to a different profile', () async {
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
      final String accountId = await seedDepositAccount(ownerProfileId: otherProfileId);
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });
  });

  group('createDetails -- interestDestinationAccountId (22/23/24)', () {
    test('22. rejects an interestDestinationAccountId belonging to a different profile', () async {
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
      final String accountId = await seedDepositAccount();
      final String otherAccountId = await accountRepo.createAccount(
        profileId: otherProfileId,
        name: 'Other Profile Bank',
        type: 'bank',
        currencyCode: 'USD',
      );
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
          interestDestinationAccountId: otherAccountId,
        ),
        throwsA(isA<DepositValidationException>()),
      );
    });

    test('23. rejects an interestDestinationAccountId in a different currency', () async {
      final String accountId = await seedDepositAccount(currencyCode: 'USD');
      final String jpyAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Wallet',
        type: 'wallet',
        currencyCode: 'JPY',
      );
      expect(
        () => depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 500,
          interestMethod: DepositInterestMethod.simple,
          interestDestinationAccountId: jpyAccountId,
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('accepts a same-currency interestDestinationAccountId', () async {
      final String accountId = await seedDepositAccount(currencyCode: 'USD');
      final String bankAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'USD Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
        interestDestinationAccountId: bankAccountId,
      );
      expect(id, isNotEmpty);
    });

    test('24. a self-referencing interestDestinationAccountId (reinvested interest) is '
        'explicitly ALLOWED, not a rejected circular relationship', () async {
      final String accountId = await seedDepositAccount(currencyCode: 'USD');
      final String id = await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
        interestDestinationAccountId: accountId, // self-link
      );
      expect(id, isNotEmpty);
      final DepositDetailsRow row = await depositRepo.requireActiveForAccount(accountId);
      expect(row.interestDestinationAccountId, accountId);
    });
  });

  group('requireActiveForAccount', () {
    test('throws DepositNotFoundException when no deposit details exist', () async {
      final String accountId = await seedDepositAccount();
      expect(
        () => depositRepo.requireActiveForAccount(accountId),
        throwsA(isA<DepositNotFoundException>()),
      );
    });

    test(
        'Bug-fix regression: startDate/maturityDate are read back UTC-flagged and calendar-'
        'stable, regardless of the host machine\'s timezone (regression for '
        'the Windows UTC+9 failure -- drift\'s default DateTimeColumn storage '
        'always hands back a *local*-flagged DateTime on read, even for a '
        'value stored as UTC; see DepositRepository._canonicalizeStoredDate)',
        () async {
      final String accountId = await seedDepositAccount();
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
      );

      final DepositDetailsRow row = await depositRepo.requireActiveForAccount(accountId);

      // The calendar-field checks alone cannot distinguish a correctly
      // re-flagged UTC value from a same-instant local one -- asserting
      // `isUtc` is what actually proves the fix, and it fails on ANY host
      // timezone (including UTC+0) without `_canonicalizeStoredDate`,
      // because drift relabels the value as local regardless of the
      // offset's magnitude.
      expect(row.startDate.isUtc, isTrue);
      expect(row.maturityDate.isUtc, isTrue);
      expect(row.startDate, DateTime.utc(2026, 1, 1));
      expect(row.maturityDate, DateTime.utc(2027, 1, 1));

      // watchForAccount is a separate read path from requireActiveForAccount
      // -- both must canonicalize identically, so both are asserted here.
      final DepositDetailsRow? watched = await depositRepo.watchForAccount(accountId).first;
      expect(watched, isNotNull);
      expect(watched!.startDate.isUtc, isTrue);
      expect(watched.maturityDate.isUtc, isTrue);
      expect(watched.startDate, DateTime.utc(2026, 1, 1));
      expect(watched.maturityDate, DateTime.utc(2027, 1, 1));
    });
  });

  group('25: derived estimates are never persisted', () {
    test('calling DepositCalculator repeatedly never mutates the stored row', () async {
      final String accountId = await seedDepositAccount(openingBalanceMinorUnits: 100000);
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 550,
        interestMethod: DepositInterestMethod.simple,
      );
      final DepositDetailsRow before = await depositRepo.requireActiveForAccount(accountId);

      // Computing an estimate (potentially many times, e.g. by a screen
      // re-rendering) must have zero persistence side effects -- there is
      // no column on this table for it to write to in the first place.
      for (int i = 0; i < 3; i++) {
        DepositCalculator.calculateSimpleInterest(
          principal: Money.fromMinorUnits(100000, 'USD'),
          interestRateBasisPoints: before.interestRateBasisPoints,
          startDateUtc: before.startDate,
          maturityDateUtc: before.maturityDate,
        );
      }

      final DepositDetailsRow after = await depositRepo.requireActiveForAccount(accountId);
      expect(after.updatedAt, before.updatedAt);
      expect(after, equals(before));
    });
  });
}
