import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_not_found_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late String profileId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);

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

  group('updateAccount — editing', () {
    test('updates name and type, leaves currency/opening balance/id/profileId/createdAt untouched',
        () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(5000, 'JPY'),
      );
      final AccountRow before = await accountRepo.requireById(accountId);

      await accountRepo.updateAccount(id: accountId, name: 'Renamed Wallet', type: 'bank');

      final AccountRow after = await accountRepo.requireById(accountId);
      expect(after.name, 'Renamed Wallet');
      expect(after.type, 'bank');
      // Never touched by updateAccount — the checkpoint's core currency
      // safety guarantee (see that method's own doc comment).
      expect(after.currencyCode, before.currencyCode);
      expect(after.openingBalanceMinorUnits, before.openingBalanceMinorUnits);
      expect(after.id, before.id);
      expect(after.profileId, before.profileId);
      expect(after.createdAt, before.createdAt);
      // Checkpoint B (schema v9): updateAccount has no
      // balanceClass/subtype parameter at all, so editing `type` from
      // 'cash' to 'bank' here must NOT recompute or change either --
      // they stay exactly what createAccount classified them as at
      // creation ('cash' legacy type -> asset/cash), even though the
      // legacy `type` string was just edited to 'bank'. This is the
      // regression test for docs/20 §12.2's immutability invariant.
      expect(after.balanceClassValue, BalanceClass.asset);
      expect(after.subtypeValue, FinancialAccountSubtype.cash);
      expect(after.balanceClassValue, before.balanceClassValue);
      expect(after.subtypeValue, before.subtypeValue);
    });

    test('updateAccount on a soft-deleted account throws AccountNotFoundException', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
     );
      await accountRepo.softDelete(accountId);

      expect(
        () => accountRepo.updateAccount(id: accountId, name: 'New Name', type: 'bank'),
        throwsA(isA<AccountNotFoundException>()),
      );
    });

    test('updateAccount on a never-existed id throws AccountNotFoundException', () async {
      expect(
        () => accountRepo.updateAccount(id: 'does-not-exist', name: 'New Name', type: 'bank'),
        throwsA(isA<AccountNotFoundException>()),
      );
    });
  });

  group('createAccount — classification (Checkpoint B)', () {
    test('cash classifies to asset/cash', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.balanceClassValue, BalanceClass.asset);
      expect(row.subtypeValue, FinancialAccountSubtype.cash);
      expect(row.isAsset, isTrue);
      expect(row.isLiability, isFalse);
    });

    test('bank classifies to asset/bank (never guessed as checking/savings)', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Main Bank',
        type: 'bank',
        currencyCode: 'USD',
      );
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.balanceClassValue, BalanceClass.asset);
      expect(row.subtypeValue, FinancialAccountSubtype.bank);
    });

    test('wallet classifies to asset/wallet', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Mobile Wallet',
        type: 'wallet',
        currencyCode: 'USD',
      );
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.balanceClassValue, BalanceClass.asset);
      expect(row.subtypeValue, FinancialAccountSubtype.wallet);
    });

    test(
      'card classifies to asset/legacyCardNeedsReview — never a liability',
      () async {
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Some Card',
          type: 'card',
          currencyCode: 'USD',
        );
        final AccountRow row = await accountRepo.requireById(accountId);
        expect(row.balanceClassValue, BalanceClass.asset);
        expect(row.isLiability, isFalse);
        expect(row.subtypeValue, FinancialAccountSubtype.legacyCardNeedsReview);
      },
    );

    test(
      'an unrecognized legacy type classifies to asset/legacyUnknownNeedsReview, never guessed',
      () async {
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Something Else',
          type: 'crypto',
          currencyCode: 'USD',
        );
        final AccountRow row = await accountRepo.requireById(accountId);
        expect(row.balanceClassValue, BalanceClass.asset);
        expect(row.subtypeValue, FinancialAccountSubtype.legacyUnknownNeedsReview);
      },
    );

    test('a newly created account has no institution and default sync metadata', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.institutionId, isNull);
      expect(row.syncVersion, 0);
      expect(row.syncStatus, 'localOnly');
    });
  });

  group('createClassifiedAccount -- Checkpoint K savings subtype', () {
    test('persists FinancialAccountSubtype.savings and round-trips it exactly', () async {
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Nest egg',
        type: 'savings',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.savings,
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(5000, 'USD'),
      );
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.balanceClassValue, BalanceClass.asset);
      expect(row.subtypeValue, FinancialAccountSubtype.savings);
      expect(row.type, 'savings');
    });

    test('a savings account and a bank account are distinct subtypes, never conflated',
        () async {
      final String savingsId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Nest egg',
        type: 'savings',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.savings,
        currencyCode: 'USD',
      );
      final String bankId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Everyday',
        type: 'bank',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.bank,
        currencyCode: 'USD',
      );
      final AccountRow savings = await accountRepo.requireById(savingsId);
      final AccountRow bank = await accountRepo.requireById(bankId);
      expect(savings.subtypeValue, FinancialAccountSubtype.savings);
      expect(bank.subtypeValue, FinancialAccountSubtype.bank);
      expect(savings.subtypeValue, isNot(bank.subtypeValue));
    });

    test(
        'an existing bank-subtype row is never heuristically reclassified as savings, even '
        'when its name/type text says "savings"', () async {
      // `classifyLegacyAccountType`/`createAccount`'s legacy path (used
      // by every pre-Checkpoint-K row) has no knowledge of `'savings'`
      // at all -- it only ever produces cash/bank/wallet/legacyCard/
      // legacyUnknown. This proves a legacy row whose free-text name or
      // `type` happens to say "savings" still classifies as plain
      // asset/bank, never guessed as the new subtype -- the brief's
      // explicit "no heuristic Bank-to-Savings conversion" requirement.
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'My Savings Account',
        type: 'bank',
        currencyCode: 'USD',
      );
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.subtypeValue, FinancialAccountSubtype.bank);
      expect(row.subtypeValue, isNot(FinancialAccountSubtype.savings));
    });

    test('a savings account appears in watchActiveForProfile -- the same stream the '
        'transaction account selector reads from', () async {
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Nest egg',
        type: 'savings',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.savings,
        currencyCode: 'USD',
      );

      final List<AccountRow> active =
          await accountRepo.watchActiveForProfile(profileId).first;
      expect(active.map((AccountRow a) => a.id), contains(accountId));

      // Closing it removes it from selection, exactly like any other
      // asset account -- lifecycle behavior is not subtype-specific.
      await accountRepo.softDelete(accountId);
      final List<AccountRow> afterClose =
          await accountRepo.watchActiveForProfile(profileId).first;
      expect(afterClose.map((AccountRow a) => a.id), isNot(contains(accountId)));
    });
  });

  group('watchById', () {
    test('emits the live row for an active account', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
     );

      final AccountRow? row = await accountRepo.watchById(accountId).first;
      expect(row, isNotNull);
      expect(row!.id, accountId);
      expect(row.name, 'Wallet');
    });

    test(
      'Account Lifecycle Checkpoint: a closed (soft-deleted) account still emits its own row -- '
      'CLOSED (isActive=false, deletedAt set), never null -- only a genuinely missing id does '
      'that (see the sibling test below, unchanged). A closed account must remain fully '
      'resolvable by id so AccountDetailScreen can show its preserved history/balance and offer '
      'Reactivate; this supersedes the old pre-checkpoint assumption that softDelete made '
      'watchById resolve to null.',
      () async {
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Wallet',
          type: 'cash',
          currencyCode: 'USD',
        );
        await accountRepo.softDelete(accountId);

        final AccountRow? row = await accountRepo.watchById(accountId).first;
        expect(row, isNotNull);
        expect(row!.id, accountId);
        expect(row.name, 'Wallet');
        expect(row.isActive, isFalse);
        expect(row.deletedAt, isNotNull);
      },
    );

    test('emits null for an id that never existed', () async {
      final AccountRow? row = await accountRepo.watchById('does-not-exist').first;
      expect(row, isNull);
    });

    test('re-emits the updated row after updateAccount', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );

      final Stream<AccountRow?> stream = accountRepo.watchById(accountId);
      final Future<List<AccountRow?>> emissions = stream.take(2).toList();

      await accountRepo.updateAccount(id: accountId, name: 'Renamed', type: 'bank');

      final List<AccountRow?> rows = await emissions;
      expect(rows.last, isNotNull);
      expect(rows.last!.name, 'Renamed');
      expect(rows.last!.type, 'bank');
    });
  });
}
