import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_not_found_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_validation_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/finance/card_network.dart';
import 'package:ai_financial_coach/core/finance/payment_instrument_type.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint D: PaymentInstrument foundation. Today's production Add
// Account UX cannot create a liability account yet (Checkpoints B/C
// only ever produce asset-classified rows), so `creditCard`-linked
// tests below seed a liability account directly through this DB
// fixture, exactly as the Checkpoint D brief's "account-class / type
// validation" section explicitly permits, rather than weakening
// `PaymentInstrumentRepository`'s own validation to accommodate UI that
// doesn't exist yet.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late PaymentInstrumentRepository instrumentRepo;
  late String profileId;
  const Uuid uuid = Uuid();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    instrumentRepo = PaymentInstrumentRepository(db, accountRepo);

    profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: 'LKR',
      livingCurrency: 'JPY',
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Seeds a liability account directly through the DB, bypassing
  /// `AccountRepository.createAccount` (which today only ever produces
  /// `asset`-classified rows) -- see this file's own doc comment.
  Future<String> seedLiabilityAccount({
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
            name: 'Test Credit Card Account',
            type: 'card',
            currencyCode: currencyCode,
            openingBalanceMinorUnits: Value<int>(openingBalanceMinorUnits),
            balanceClass: const Value<String>('liability'),
            subtype: const Value<String>('legacyCardNeedsReview'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<String> seedInstitution({String? ownerProfileId}) async {
    final String id = uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await db.into(db.financialInstitutions).insert(
          FinancialInstitutionsCompanion.insert(
            id: id,
            profileId: ownerProfileId ?? profileId,
            name: 'Test Bank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Seeds a second, deliberately foreign `Profiles` row directly through
  /// the DB fixture -- never via `ProfileRepository.createProfile()`, which
  /// enforces the single-local-profile invariant that a real second local
  /// profile can never exist. These cross-profile tests need a foreign
  /// `profileId` to exist only so `PaymentInstrumentRepository`'s
  /// account/institution-profile-mismatch validation has something to
  /// reject; they are not exercising `ProfileRepository` at all, so
  /// bypassing it here does not weaken that invariant.
  Future<String> seedOtherProfile() async {
    final String id = uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: id,
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
    return id;
  }

  group('createInstrument -- account-class / type validation', () {
    test('1. a debit card can link to an asset account', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Everyday debit card',
      );
      expect(id, isNotEmpty);
    });

    test('2. a cash card can link to an asset account', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Cash',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.cashCard,
        nickname: 'Cash card',
      );
      expect(id, isNotEmpty);
    });

    test('3. a credit card can link to a liability account', () async {
      final String accountId = await seedLiabilityAccount();
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.creditCard,
        nickname: 'Rewards card',
      );
      expect(id, isNotEmpty);
    });

    test('4. a credit card linked to an asset account is rejected', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.creditCard,
          nickname: 'Bad card',
        ),
        throwsA(isA<PaymentInstrumentValidationException>()),
      );
    });

    test('5. a debit card linked to a liability account is rejected', () async {
      final String accountId = await seedLiabilityAccount();
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Bad debit',
        ),
        throwsA(isA<PaymentInstrumentValidationException>()),
      );
    });

    test('6. a payment service may link to either an asset or a liability account', () async {
      final String assetAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'wallet',
        currencyCode: 'USD',
      );
      final String liabilityAccountId = await seedLiabilityAccount();

      final String assetLinkedId = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: assetAccountId,
        instrumentType: PaymentInstrumentType.paymentService,
        nickname: 'Wallet app (asset-funded)',
      );
      final String liabilityLinkedId = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: liabilityAccountId,
        instrumentType: PaymentInstrumentType.paymentService,
        nickname: 'Wallet app (credit-funded)',
      );
      expect(assetLinkedId, isNotEmpty);
      expect(liabilityLinkedId, isNotEmpty);
    });

    test('7. exactly one account is required structurally -- the created row names '
        'exactly the one account passed in, via a single non-nullable accountId column',
        () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
      );
      final PaymentInstrumentRow row = await instrumentRepo.requireActiveById(id);
      expect(row.accountId, accountId);
    });

    test('8. an optional institution works', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String institutionId = await seedInstitution();
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
        institutionId: institutionId,
      );
      final PaymentInstrumentRow row = await instrumentRepo.requireActiveById(id);
      expect(row.institutionId, institutionId);
    });

    test('9. an institution belonging to a different profile is rejected', () async {
      final String otherProfileId = await seedOtherProfile();
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String otherProfilesInstitutionId = await seedInstitution(ownerProfileId: otherProfileId);
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
          institutionId: otherProfilesInstitutionId,
        ),
        throwsA(isA<PaymentInstrumentValidationException>()),
      );
    });

    test('10. an account belonging to a different profile is rejected', () async {
      final String otherProfileId = await seedOtherProfile();
      final String otherProfilesAccountId = await accountRepo.createAccount(
        profileId: otherProfileId,
        name: 'Their Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: otherProfilesAccountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
        ),
        throwsA(isA<PaymentInstrumentValidationException>()),
      );
    });
  });

  group('createInstrument -- sensitive-data boundary (last4 / expiry)', () {
    late String accountId;
    setUp(() async {
      accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
    });

    test('11. last4 null is allowed', () async {
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
      );
      final PaymentInstrumentRow row = await instrumentRepo.requireActiveById(id);
      expect(row.last4, isNull);
    });

    test('12. a valid 4-digit last4 is accepted', () async {
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
        last4: '1234',
      );
      final PaymentInstrumentRow row = await instrumentRepo.requireActiveById(id);
      expect(row.last4, '1234');
    });

    test('13. an invalid last4 is rejected', () async {
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
          last4: '12',
        ),
        throwsArgumentError,
      );
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
          last4: 'abcd',
        ),
        throwsArgumentError,
      );
    });

    test('14. expiry null/null is accepted', () async {
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
      );
      final PaymentInstrumentRow row = await instrumentRepo.requireActiveById(id);
      expect(row.expiryMonth, isNull);
      expect(row.expiryYear, isNull);
    });

    test('15. a valid expiry is accepted', () async {
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
        expiryMonth: 7,
        expiryYear: 2030,
      );
      final PaymentInstrumentRow row = await instrumentRepo.requireActiveById(id);
      expect(row.expiryMonth, 7);
      expect(row.expiryYear, 2030);
    });

    test('16. an invalid month is rejected', () async {
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
          expiryMonth: 13,
          expiryYear: 2030,
        ),
        throwsArgumentError,
      );
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
          expiryMonth: 0,
          expiryYear: 2030,
        ),
        throwsArgumentError,
      );
    });

    test('17. a partial expiry (only one of month/year) is rejected', () async {
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
          expiryMonth: 7,
        ),
        throwsArgumentError,
      );
      expect(
        () => instrumentRepo.createInstrument(
          profileId: profileId,
          accountId: accountId,
          instrumentType: PaymentInstrumentType.debitCard,
          nickname: 'Card',
          expiryYear: 2030,
        ),
        throwsArgumentError,
      );
    });
  });

  group('updateMetadata / lifecycle', () {
    test('18. a metadata update preserves the immutable account/type/profile', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Old nickname',
        network: CardNetwork.visa,
      );
      await instrumentRepo.updateMetadata(
        id: id,
        nickname: 'New nickname',
        network: CardNetwork.mastercard,
        last4: '9999',
      );
      final PaymentInstrumentRow row = await instrumentRepo.requireActiveById(id);
      expect(row.nickname, 'New nickname');
      expect(row.networkValue, CardNetwork.mastercard);
      expect(row.last4, '9999');
      // Immutable fields are exactly as created -- updateMetadata's
      // signature has no way to change any of them.
      expect(row.accountId, accountId);
      expect(row.profileId, profileId);
      expect(row.instrumentTypeValue, PaymentInstrumentType.debitCard);
    });

    test('19. a soft-deleted instrument is excluded from active selection', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
      );
      await instrumentRepo.softDelete(id);

      final List<PaymentInstrumentRow> active =
          await instrumentRepo.watchActiveForAccount(accountId).first;
      expect(active, isEmpty);
      final List<PaymentInstrumentRow> activeForProfile =
          await instrumentRepo.watchActiveForProfile(profileId).first;
      expect(activeForProfile, isEmpty);
      expect(
        () => instrumentRepo.requireActiveById(id),
        throwsA(isA<PaymentInstrumentNotFoundException>()),
      );
    });

    test('20. an archived instrument remains retrievable for historical resolution', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String id = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card',
      );
      await instrumentRepo.softDelete(id);

      final PaymentInstrumentRow? row = await instrumentRepo.findByIdIncludingDeleted(id);
      expect(row, isNotNull);
      expect(row!.id, id);
      expect(row.deletedAt, isNotNull);
    });
  });

  group('active-selection ordering / basic watch behavior', () {
    test('watchActiveForAccount only returns instruments linked to that account', () async {
      final String accountA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking A',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String accountB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking B',
        type: 'bank',
        currencyCode: 'USD',
      );
      await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountA,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card A',
      );
      await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountB,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Card B',
      );
      final List<PaymentInstrumentRow> forA = await instrumentRepo.watchActiveForAccount(accountA).first;
      expect(forA, hasLength(1));
      expect(forA.single.nickname, 'Card A');
    });
  });
}
