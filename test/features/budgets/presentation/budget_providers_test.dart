import 'dart:async';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_calculation.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/budgets/presentation/budget_providers.dart';
import 'package:ai_financial_coach/features/onboarding/presentation/profile_providers.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Plain `test()`s, not `testWidgets()`s -- see
// `test/core/dashboard/dashboard_providers_test.dart`'s doc comment for
// why (avoids Flutter's FakeAsync test clock entirely).
//
// `livingCurrencyOverallBudgetProvider` is a plain (synchronous)
// `Provider`, but it internally watches an `AutoDisposeStreamProvider`
// family (`_overallBudgetRowProvider`) that has never been watched
// before at the point each test first reads it. Awaiting
// `activeProfileProvider.future`/`ledgerProvider.future` beforehand
// only guarantees THOSE two providers have resolved -- it says
// nothing about the freshly-created family stream, which needs at
// least one more event-loop turn to deliver its first value after
// being watched for the first time. A single synchronous
// `container.read(livingCurrencyOverallBudgetProvider)` right after
// can therefore observe an in-flight `AsyncLoading()` rather than the
// settled result -- exactly mirroring what a real widget would show
// for one build before Riverpod notifies it of the resolved value.
// `readSettledBudget` below waits for that same notification a
// widget would rely on, instead of guessing how many pumps are enough.

void main() {
  /// Reads [livingCurrencyOverallBudgetProvider], and if it is still
  /// settling (its dependency chain includes a family `StreamProvider`
  /// being watched for the first time -- see the file doc comment
  /// above), listens for it to leave `AsyncLoading` before reading it
  /// again. This is the non-widget-test equivalent of a widget
  /// rebuilding once Riverpod notifies it of a resolved value -- it
  /// does not change what is asserted, only how long the test waits
  /// before asserting it.
  Future<AsyncValue<BudgetCalculation?>> readSettledBudget(ProviderContainer container) async {
    AsyncValue<BudgetCalculation?> value = container.read(livingCurrencyOverallBudgetProvider);
    if (!value.isLoading) return value;

    final Completer<void> settled = Completer<void>();
    final ProviderSubscription<AsyncValue<BudgetCalculation?>> subscription = container.listen<
        AsyncValue<BudgetCalculation?>>(
      livingCurrencyOverallBudgetProvider,
      (AsyncValue<BudgetCalculation?>? previous, AsyncValue<BudgetCalculation?> next) {
        if (!next.isLoading && !settled.isCompleted) settled.complete();
      },
    );
    try {
      await settled.future;
      value = container.read(livingCurrencyOverallBudgetProvider);
    } finally {
      subscription.close();
    }
    return value;
  }

  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late BudgetRepository budgetRepo;
  late ProviderContainer container;

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> seedProfile({required String living, required String home}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    budgetRepo = BudgetRepository(db);
    container = ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    return profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: home,
      livingCurrency: living,
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
  }

  group('livingCurrencyOverallBudgetProvider', () {
    test('no budget configured -> an honest null, never a fabricated zero budget', () async {
      await seedProfile(living: 'JPY', home: 'LKR');
      await container.read(activeProfileProvider.future);

      final AsyncValue<BudgetCalculation?> result = await readSettledBudget(container);
      expect(result.hasValue, isTrue);
      expect(result.requireValue, isNull);
    });

    test('a configured living-currency budget produces a real summary reflecting actual spend',
        () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'LKR');
      final String walletId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );

      final BudgetMonth currentMonth = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await budgetRepo.setOverallBudget(
        profileId: profileId,
        month: currentMonth,
        amount: Money.fromMinorUnits(120000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(30000, 'JPY'),
        occurredAtUtc: DateTime.now().toUtc(),
      );

      await container.read(activeProfileProvider.future);
      await container.read(ledgerProvider.future);

      final AsyncValue<BudgetCalculation?> result = await readSettledBudget(container);
      expect(result.hasValue, isTrue);
      final BudgetCalculation calc = result.requireValue!;
      expect(calc.budgeted, Money.fromMinorUnits(120000, 'JPY'));
      expect(calc.spent, Money.fromMinorUnits(30000, 'JPY'));
      expect(calc.remaining, Money.fromMinorUnits(90000, 'JPY'));
    });

    test('a budget configured in a different currency never contaminates the living-currency '
        'summary', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      final BudgetMonth currentMonth = BudgetMonth.fromUtc(DateTime.now().toUtc());

      // Only a USD budget exists -- living currency is JPY.
      await budgetRepo.setOverallBudget(
        profileId: profileId,
        month: currentMonth,
        amount: Money.fromMinorUnits(50000, 'USD'),
      );

      await container.read(activeProfileProvider.future);
      await container.read(ledgerProvider.future);

      final AsyncValue<BudgetCalculation?> result = await readSettledBudget(container);
      expect(result.hasValue, isTrue);
      expect(result.requireValue, isNull); // no JPY budget configured -> honest empty state
    });
  });
}
