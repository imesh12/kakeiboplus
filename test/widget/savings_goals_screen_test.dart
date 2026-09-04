import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/presentation/savings_goals_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  Future<(AppDatabase, String)> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
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
    return (db, profileId);
  }

  Widget appWithGoals(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SavingsGoalsScreen()),
    );
  }

  /// Same deterministic shutdown sequence as
  /// `test/widget/budgets_screen_test.dart`'s `disposeInOrder`: unmount,
  /// then dispose, then one `pumpAndSettle()` so Drift's
  /// `StreamQueryStore.markAsClosed` `Timer.zero` fires before
  /// `db.close()`.
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('the empty state is shown when there are no goals yet', (tester) async {
    final (AppDatabase db, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('No savings goals yet'), findsOneWidget);
  });

  testWidgets('creating a goal with no target date shows it in the list', (tester) async {
    final (AppDatabase db, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addGoalFab')));
    await tester.pumpAndSettle();
    expect(find.text('New savings goal'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('goalNameField')), 'Emergency Fund');
    await tester.enterText(find.byKey(const Key('goalTargetAmountField')), '120000');
    await tester.tap(find.byKey(const Key('saveGoal')));
    await tester.pumpAndSettle();

    expect(find.text('New savings goal'), findsNothing); // dialog closed
    expect(find.text('Emergency Fund'), findsOneWidget);
    expect(find.textContaining('¥120,000'), findsOneWidget);
    expect(find.textContaining('0%'), findsOneWidget); // nothing saved yet
  });

  testWidgets('the goal name field rejects an empty/whitespace-only name', (tester) async {
    final (AppDatabase db, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addGoalFab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalNameField')), '   ');
    await tester.enterText(find.byKey(const Key('goalTargetAmountField')), '120000');
    await tester.tap(find.byKey(const Key('saveGoal')));
    await tester.pumpAndSettle();

    // The dialog is still open -- form validation blocked the save.
    expect(find.text('New savings goal'), findsOneWidget);
  });

  testWidgets('a goal created with a target date shows it in the list', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Holiday Fund',
      targetAmount: Money.fromMinorUnits(80000, 'JPY'),
      targetDate: DateTime.utc(2026, 12, 25),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    expect(find.text('Holiday Fund'), findsOneWidget);
    expect(find.textContaining('¥80,000'), findsOneWidget);
  });

  testWidgets('the goals screen lays out without overflow on a narrow (320px-wide) screen '
      'with several goals', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    await goalRepo.createGoal(
      profileId: profileId,
      name: 'A very long savings goal name that could wrap awkwardly',
      targetAmount: Money.fromMinorUnits(1000000, 'JPY'),
      targetDate: DateTime.utc(2026, 12, 25),
    );
    await goalRepo.createGoal(
      profileId: profileId,
      name: 'Short Goal',
      targetAmount: Money.fromMinorUnits(50000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    final Object? overflowException = tester.takeException();
    if (overflowException != null) {
      fail('Narrow-screen (320px) goals screen layout threw an exception:\n\n$overflowException');
    }
  });
}
