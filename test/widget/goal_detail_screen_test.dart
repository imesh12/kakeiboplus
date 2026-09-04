import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/presentation/goal_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Deliberately does NOT exercise `GoalDetailScreen`'s delete-goal flow
// (`_confirmDelete`) -- that calls `context.pop()`, which requires a
// `GoRouter` ancestor this file's plain `MaterialApp(home: ...)` harness
// doesn't provide (matching `test/widget/budgets_screen_test.dart`,
// which likewise never taps into cross-screen navigation). The
// underlying repository behavior soft-delete exercises is already
// covered by `test/core/database/repositories/savings_goal_repository_test.dart`.

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

  Widget appWithGoalDetail(ProviderContainer container, String goalId) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: GoalDetailScreen(goalId: goalId)),
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('shows a freshly-created goal with no contributions as 0% in progress',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final String goalId = await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Fund'), findsWidgets); // app bar title + body
    expect(find.textContaining('of ¥100,000'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.text('No contributions yet.'), findsOneWidget);
  });

  testWidgets('adding a contribution updates saved and the contribution history', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final String goalId = await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addContributionFab')));
    await tester.pumpAndSettle();
    expect(find.text('Add a contribution'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('contributionAmountField')), '30000');
    await tester.tap(find.byKey(const Key('saveContribution')));
    await tester.pumpAndSettle();

    expect(find.text('Add a contribution'), findsNothing); // dialog closed
    expect(find.text('¥30,000'), findsWidgets); // headline saved amount + history row
    expect(find.text('No contributions yet.'), findsNothing);
  });

  testWidgets('deleting a contribution removes it from history and reduces saved', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(
      goalId: goalId,
      amount: Money.fromMinorUnits(30000, 'JPY'),
      contributedAt: DateTime.utc(2026, 1, 1),
    );
    final String secondId = await contributionRepo.addContribution(
      goalId: goalId,
      amount: Money.fromMinorUnits(20000, 'JPY'),
      contributedAt: DateTime.utc(2026, 2, 1),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('contributionTile_$secondId')), findsOneWidget);
    // Scoped to the headline saved-amount widget specifically --
    // "Remaining" (target 100000 - saved 50000) also reads ¥50,000 at
    // this point, so a plain `find.text('¥50,000')` matches two
    // widgets. See `goal_detail_screen.dart`'s `goalSavedAmount` key.
    expect(
      tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
      '¥50,000', // 30000 + 20000, headline saved
    );

    await tester.tap(find.byKey(Key('deleteContribution_$secondId')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('contributionTile_$secondId')), findsNothing);
    expect(find.text('¥30,000'), findsWidgets); // saved dropped back to just the first
  });

  testWidgets('editing a goal updates the displayed name and target amount', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final String goalId = await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Old Name',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editGoal')));
    await tester.pumpAndSettle();
    expect(find.text('Edit goal'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('editGoalNameField')), 'New Name');
    await tester.enterText(find.byKey(const Key('editGoalTargetAmountField')), '200000');
    await tester.tap(find.byKey(const Key('saveEditGoal')));
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsNothing); // dialog closed
    expect(find.text('New Name'), findsWidgets);
    expect(find.textContaining('of ¥200,000'), findsOneWidget);
  });

  testWidgets('a goal that no longer exists (e.g. soft-deleted) shows an unavailable state',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Temporary',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    await goalRepo.softDeleteGoal(goalId);

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(find.text('This goal is no longer available.'), findsOneWidget);
    expect(find.byKey(const Key('addContributionFab')), findsNothing);
    expect(find.byKey(const Key('editGoal')), findsNothing);
  });

  testWidgets('the goal detail screen lays out without overflow on a narrow (320px-wide) screen '
      'with a target date, milestones, and contribution history', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'A very long savings goal name that could wrap awkwardly on a narrow screen',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      targetDate: DateTime.utc(2026, 12, 25),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(60000, 'JPY'));

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    final Object? overflowException = tester.takeException();
    if (overflowException != null) {
      fail('Narrow-screen (320px) goal detail layout threw an exception:\n\n$overflowException');
    }
  });
}
