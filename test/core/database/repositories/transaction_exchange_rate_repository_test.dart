import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/fx_snapshot_already_exists_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_exchange_rate_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_snapshot.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.1 (FX Money Engine & Historical Exchange-Rate Foundation),
// Phase 6.I (historical immutability) and Phase 6.J (accounting
// invariants: merely attaching an FX snapshot must not change balances,
// income/expense totals, transfer exclusion, or cross-currency transfer
// rejection).
//
// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository txRepo;
  late TransactionExchangeRateRepository fxRepo;
  late String profileId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    txRepo = TransactionRepository(db, accountRepo);
    fxRepo = TransactionExchangeRateRepository(db);

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

  group('TransactionExchangeRateRepository — DateTime instants are always UTC', () {
    // Regression coverage for the "+9 hours" symptom seen on a UTC+9
    // Windows machine: Drift's default (non-text) DateTime storage
    // round-trips the correct INSTANT but reads it back tagged local,
    // not UTC (see the repository's own class doc). Dart's `DateTime.==`
    // distinguishes a UTC-tagged value from a local-tagged value even
    // when they represent the exact same moment, so without an explicit
    // re-tag, a same-instant read-back value fails `==` against a
    // UTC-tagged expectation and prints as local wall-clock time (e.g.
    // 21:00 instead of 12:00 on a UTC+9 machine). None of the tests
    // below hardcode any UTC offset or assume a particular machine
    // timezone -- they must pass identically everywhere.

    test('a UTC providerTimestamp round-trips as the exact same instant, re-tagged UTC', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      final DateTime observed = DateTime.utc(2026, 1, 1, 12, 0, 0);
      await fxRepo.attach(
        transactionId: txId,
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
        convertedAmount: Money.fromMinorUnits(7500, 'JPY'),
        source: 'test-provider',
        providerTimestamp: observed,
        fetchedAt: DateTime.utc(2026, 1, 1, 12, 0, 1),
      );

      final FxSnapshot snapshot = (await fxRepo.forTransaction(txId))!;
      expect(snapshot.providerTimestamp.isUtc, isTrue);
      expect(snapshot.providerTimestamp.isAtSameMomentAs(observed), isTrue);
      // Exact `==`, not just `isAtSameMomentAs` -- proves the value is
      // genuinely UTC-tagged, not merely the same instant under a
      // different tag (which `isAtSameMomentAs` alone would not catch).
      expect(snapshot.providerTimestamp, observed);
    });

    test('a UTC fetchedAt round-trips as the exact same instant, re-tagged UTC', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      // Whole seconds only -- Drift's default (non-text) DateTime
      // storage for this project persists a unix-SECONDS INTEGER (see
      // `recurring_migration_test.dart`'s "_epochSeconds" comment), so a
      // sub-second component here would be truncated on the round trip
      // and fail `isAtSameMomentAs` for a reason that has nothing to do
      // with the UTC-tagging bug this group exists to catch -- every
      // other DateTime literal in this codebase already sticks to
      // whole-second precision for the same reason.
      final DateTime fetched = DateTime.utc(2026, 1, 1, 12, 0, 1);
      await fxRepo.attach(
        transactionId: txId,
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
        convertedAmount: Money.fromMinorUnits(7500, 'JPY'),
        source: 'test-provider',
        providerTimestamp: DateTime.utc(2026, 1, 1, 12, 0, 0),
        fetchedAt: fetched,
      );

      final FxSnapshot snapshot = (await fxRepo.forTransaction(txId))!;
      expect(snapshot.fetchedAt.isUtc, isTrue);
      expect(snapshot.fetchedAt.isAtSameMomentAs(fetched), isTrue);
      expect(snapshot.fetchedAt, fetched);
    });

    test(
      'a non-UTC-tagged (local) input DateTime is normalized to the same UTC instant -- '
      'independent of whatever timezone this test happens to run in',
      () async {
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Wallet',
          type: 'cash',
          currencyCode: 'USD',
        );
        final String txId = await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(5000, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );

        // Deliberately NOT `DateTime.utc(...)` -- a local-tagged
        // DateTime, whatever this machine's timezone offset actually
        // is. Its `isAtSameMomentAs` comparison below is the
        // timezone-invariant check; nothing here assumes UTC+9 or any
        // other specific offset.
        final DateTime localInput = DateTime(2026, 3, 15, 8, 30, 0);
        expect(localInput.isUtc, isFalse, reason: 'sanity check: this must be a local DateTime');

        await fxRepo.attach(
          transactionId: txId,
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
          convertedAmount: Money.fromMinorUnits(7500, 'JPY'),
          source: 'test-provider',
          providerTimestamp: localInput,
          fetchedAt: localInput,
        );

        final FxSnapshot snapshot = (await fxRepo.forTransaction(txId))!;
        expect(snapshot.providerTimestamp.isUtc, isTrue);
        // The represented INSTANT must be unchanged by normalization --
        // only the tag changes, never the moment.
        expect(snapshot.providerTimestamp.isAtSameMomentAs(localInput), isTrue);
      },
    );
  });

  group('TransactionExchangeRateRepository — Phase 6.I: historical immutability', () {
    test('forTransaction returns null before anything is attached', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      expect(await fxRepo.forTransaction(txId), isNull);
    });

    test(
      'attaching rate A, then attempting to introduce newer rate B, leaves the original '
      'snapshot (rate A and its converted amount) completely unchanged',
      () async {
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Wallet',
          type: 'cash',
          currencyCode: 'USD',
        );
        final String txId = await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(5000, 'USD'), // $50.00
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );

        // 1. Attach rate A: 1 USD = 150.00 JPY, observed 2026-01-01.
        final FxRate rateA = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150');
        final Money convertedA = Money.fromMinorUnits(7500, 'JPY'); // $50 * 150 = ¥7500
        final DateTime observedA = DateTime.utc(2026, 1, 1, 12);
        final DateTime fetchedA = DateTime.utc(2026, 1, 1, 12, 0, 1);

        await fxRepo.attach(
          transactionId: txId,
          rate: rateA,
          convertedAmount: convertedA,
          source: 'test-provider',
          providerTimestamp: observedA,
          fetchedAt: fetchedA,
        );

        // 2. Read it back and confirm it matches rate A exactly.
        final FxSnapshot? afterA = await fxRepo.forTransaction(txId);
        expect(afterA, isNotNull);
        expect(afterA!.rate, rateA);
        expect(afterA.convertedAmount, convertedA);
        expect(afterA.providerTimestamp, observedA);
        expect(afterA.source, 'test-provider');

        // 3. "Introduce a newer rate B" -- a later market rate becoming
        // available. There is deliberately no update/replace path, so
        // the only way this could happen is a second attach() call,
        // which must be rejected rather than silently overwriting A.
        final FxRate rateB = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '151.75');
        final Money convertedB = Money.fromMinorUnits(7587, 'JPY'); // a different converted amount
        final DateTime observedB = DateTime.utc(2026, 6, 1, 9);

        await expectLater(
          fxRepo.attach(
            transactionId: txId,
            rate: rateB,
            convertedAmount: convertedB,
            source: 'test-provider',
            providerTimestamp: observedB,
            fetchedAt: observedB,
          ),
          throwsA(isA<FxSnapshotAlreadyExistsException>()),
        );

        // 4. Prove the historical snapshot still contains A, byte-for-byte
        // -- rate B never took effect.
        final FxSnapshot? afterAttemptedB = await fxRepo.forTransaction(txId);
        expect(afterAttemptedB, isNotNull);
        expect(afterAttemptedB!.rate, rateA);
        expect(afterAttemptedB.rate, isNot(rateB));
        expect(afterAttemptedB.convertedAmount, convertedA);
        expect(afterAttemptedB.convertedAmount, isNot(convertedB));
        expect(afterAttemptedB.providerTimestamp, observedA);
      },
    );

    test('attach rejects a convertedAmount whose currency does not match the rate\'s quote '
        'currency', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      expect(
        () => fxRepo.attach(
          transactionId: txId,
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
          convertedAmount: Money.fromMinorUnits(7500, 'EUR'), // wrong currency -- should be JPY
          source: 'test-provider',
          providerTimestamp: DateTime.utc(2026, 1, 1),
          fetchedAt: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('TransactionExchangeRateRepository — Phase 6.J: accounting invariants preserved', () {
    test('attaching an FX snapshot to an expense does not change the account balance', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(100000, 'USD'), // $1000.00
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'), // $50.00
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      final LedgerAccount account = (await accountRepo.requireById(accountId)).toLedgerAccount();
      final List<LedgerTransaction> before = await txRepo.watchLedgerForProfile(profileId).first;
      final Money balanceBefore = FinanceEngine.accountBalance(account, before);

      await fxRepo.attach(
        transactionId: txId,
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
        convertedAmount: Money.fromMinorUnits(7500, 'JPY'),
        source: 'test-provider',
        providerTimestamp: DateTime.utc(2026, 1, 1),
        fetchedAt: DateTime.utc(2026, 1, 1),
      );

      final List<LedgerTransaction> after = await txRepo.watchLedgerForProfile(profileId).first;
      final Money balanceAfter = FinanceEngine.accountBalance(account, after);

      expect(balanceAfter, balanceBefore);
      expect(balanceAfter, Money.fromMinorUnits(95000, 'USD')); // $1000 - $50, unaffected by FX
    });

    test('attaching an FX snapshot does not change income/expense totals', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String expenseId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(3000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await txRepo.recordIncome(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(200000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );

      final List<LedgerTransaction> before = await txRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totalsBefore =
          FinanceEngine.incomeExpenseTotals(before, currencyCode: 'USD');

      await fxRepo.attach(
        transactionId: expenseId,
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
        convertedAmount: Money.fromMinorUnits(4500, 'JPY'),
        source: 'test-provider',
        providerTimestamp: DateTime.utc(2026, 1, 1),
        fetchedAt: DateTime.utc(2026, 1, 1),
      );

      final List<LedgerTransaction> after = await txRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totalsAfter =
          FinanceEngine.incomeExpenseTotals(after, currencyCode: 'USD');

      expect(totalsAfter.income, totalsBefore.income);
      expect(totalsAfter.expense, totalsBefore.expense);
      expect(totalsAfter.expense, Money.fromMinorUnits(3000, 'USD'));
      expect(totalsAfter.income, Money.fromMinorUnits(200000, 'USD'));
    });

    test('a transfer remains excluded from income/expense totals even after an FX snapshot is '
        'attached to it', () async {
      final String sourceAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String destinationAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Savings',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String transferId = await txRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        amount: Money.fromMinorUnits(10000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      await fxRepo.attach(
        transactionId: transferId,
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
        convertedAmount: Money.fromMinorUnits(15000, 'JPY'),
        source: 'test-provider',
        providerTimestamp: DateTime.utc(2026, 1, 1),
        fetchedAt: DateTime.utc(2026, 1, 1),
      );

      final List<LedgerTransaction> transactions =
          await txRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals =
          FinanceEngine.incomeExpenseTotals(transactions, currencyCode: 'USD');

      // The release-gate invariant: a transfer never counts as income or
      // expense, FX snapshot or not.
      expect(totals.income, Money.zero('USD'));
      expect(totals.expense, Money.zero('USD'));
    });

    test('existing cross-currency transfer rejection is unaffected by the FX foundation being '
        'present in the codebase', () async {
      final String usdAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'US Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String jpyAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Japan Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );

      // CP9.1 explicitly keeps transfers same-currency-only -- this must
      // still throw exactly as it did before this checkpoint (ADR-019),
      // and nothing about FxRate/FxConverter/FxSnapshot changes that.
      expect(
        () => txRepo.recordTransfer(
          profileId: profileId,
          sourceAccountId: usdAccountId,
          destinationAccountId: jpyAccountId,
          amount: Money.fromMinorUnits(10000, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });
  });
}
