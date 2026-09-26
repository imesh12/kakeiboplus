import 'dart:async';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/domain/savings_goal_calculation.dart';
import 'package:ai_financial_coach/features/goals/domain/savings_goal_status.dart';
import 'package:ai_financial_coach/features/goals/presentation/savings_goal_providers.dart';
import 'package:ai_financial_coach/features/onboarding/presentation/profile_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Plain `test()`s, not `testWidgets()`s -- see
// `test/features/budgets/presentation/budget_providers_test.dart`'s doc
// comment for why.

/// A minimal, directly-constructed [SavingsGoalRow] for the pure
/// [selectHomeGoalSummary] tests below -- no database involved. Every
/// field not relevant to a given test is given an arbitrary fixed value.
SavingsGoalRow _fakeGoalRow({
  required String id,
  DateTime? targetDate,
  required DateTime createdAt,
}) {
  return SavingsGoalRow(
    id: id,
    profileId: 'profile-1',
    name: 'Goal $id',
    targetAmountMinorUnits: 100000,
    currencyCode: 'JPY',
    targetDate: targetDate,
    createdAt: createdAt,
    updatedAt: createdAt,
    deletedAt: null,
    syncVersion: 0,
    syncStatus: 'localOnly',
  );
}

SavingsGoalSummary _summary({
  required String id,
  required SavingsGoalStatus status,
  DateTime? targetDate,
  required DateTime createdAt,
}) {
  final SavingsGoalRow goal = _fakeGoalRow(id: id, targetDate: targetDate, createdAt: createdAt);
  final Money target = Money.fromMinorUnits(100000, 'JPY');
  final Money saved = status == SavingsGoalStatus.completed
      ? target
      : Money.fromMinorUnits(1000, 'JPY');
  return SavingsGoalSummary(
    goal: goal,
    calculation: SavingsGoalCalculation(
      target: target,
      saved: saved,
      remaining: status == SavingsGoalStatus.completed ? Money.zero('JPY') : target - saved,
      status: status,
      recommendedDailyContribution: null,
      reachedMilestones: const <int>[],
    ),
  );
}

void main() {
  group('selectHomeGoalSummary (pure function)', () {
    test('no goals -> empty', () {
      final GoalHomeSelection selection = selectHomeGoalSummary(const <SavingsGoalSummary>[]);
      expect(selection.kind, GoalHomeSelectionKind.empty);
      expect(selection.summary, isNull);
    });

    test('every goal completed -> allCompleted, never a "most recent" guess', () {
      final List<SavingsGoalSummary> summaries = <SavingsGoalSummary>[
        _summary(
          id: 'a',
          status: SavingsGoalStatus.completed,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        _summary(
          id: 'b',
          status: SavingsGoalStatus.completed,
          createdAt: DateTime.utc(2026, 6, 1),
        ),
      ];
      final GoalHomeSelection selection = selectHomeGoalSummary(summaries);
      expect(selection.kind, GoalHomeSelectionKind.allCompleted);
      expect(selection.summary, isNull);
    });

    test('an overdue goal is prioritized over an inProgress goal', () {
      final List<SavingsGoalSummary> summaries = <SavingsGoalSummary>[
        _summary(
          id: 'in-progress',
          status: SavingsGoalStatus.inProgress,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        _summary(
          id: 'overdue',
          status: SavingsGoalStatus.overdue,
          createdAt: DateTime.utc(2026, 3, 1),
        ),
      ];
      final GoalHomeSelection selection = selectHomeGoalSummary(summaries);
      expect(selection.kind, GoalHomeSelectionKind.priorityGoal);
      expect(selection.summary!.id, 'overdue');
    });

    test('completed goals never compete with unfinished goals for priority', () {
      final List<SavingsGoalSummary> summaries = <SavingsGoalSummary>[
        _summary(
          id: 'completed',
          status: SavingsGoalStatus.completed,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        _summary(
          id: 'in-progress',
          status: SavingsGoalStatus.inProgress,
          createdAt: DateTime.utc(2026, 6, 1),
        ),
      ];
      final GoalHomeSelection selection = selectHomeGoalSummary(summaries);
      expect(selection.kind, GoalHomeSelectionKind.priorityGoal);
      expect(selection.summary!.id, 'in-progress');
    });

    test('within the same status, the sooner target date wins', () {
      final List<SavingsGoalSummary> summaries = <SavingsGoalSummary>[
        _summary(
          id: 'later',
          status: SavingsGoalStatus.inProgress,
          targetDate: DateTime.utc(2027, 1, 1),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        _summary(
          id: 'sooner',
          status: SavingsGoalStatus.inProgress,
          targetDate: DateTime.utc(2026, 6, 1),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      final GoalHomeSelection selection = selectHomeGoalSummary(summaries);
      expect(selection.summary!.id, 'sooner');
    });

    test('a null target date sorts after every goal that has one', () {
      final List<SavingsGoalSummary> summaries = <SavingsGoalSummary>[
        _summary(
          id: 'no-date',
          status: SavingsGoalStatus.inProgress,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        _summary(
          id: 'has-date',
          status: SavingsGoalStatus.inProgress,
          targetDate: DateTime.utc(2027, 1, 1),
          createdAt: DateTime.utc(2026, 6, 1),
        ),
      ];
      final GoalHomeSelection selection = selectHomeGoalSummary(summaries);
      expect(selection.summary!.id, 'has-date');
    });

    test('createdAt ascending breaks a tie between two goals with no target date', () {
      final List<SavingsGoalSummary> summaries = <SavingsGoalSummary>[
        _summary(
          id: 'newer',
          status: SavingsGoalStatus.inProgress,
          createdAt: DateTime.utc(2026, 6, 1),
        ),
        _summary(
          id: 'older',
          status: SavingsGoalStatus.inProgress,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      final GoalHomeSelection selection = selectHomeGoalSummary(summaries);
      expect(selection.summary!.id, 'older');
    });
  });

  group('provider integration', () {
    /// Reads [goalSummariesProvider], and if it's still settling (its
    /// dependency chain includes stream providers being watched for the
    /// first time -- see `budget_providers_test.dart`'s doc comment for
    /// the same underlying reason), listens for it to leave
    /// `AsyncLoading` before reading it again.
    Future<AsyncValue<List<SavingsGoalSummary>>> readSettledSummaries(
      ProviderContainer container,
    ) async {
      AsyncValue<List<SavingsGoalSummary>> value = container.read(goalSummariesProvider);
      if (!value.isLoading) return value;

      final Completer<void> settled = Completer<void>();
      final ProviderSubscription<AsyncValue<List<SavingsGoalSummary>>> subscription = container
          .listen<AsyncValue<List<SavingsGoalSummary>>>(goalSummariesProvider, (previous, next) {
        if (!next.isLoading && !settled.isCompleted) settled.complete();
      });
      try {
        await settled.future;
        value = container.read(goalSummariesProvider);
      } finally {
        subscription.close();
      }
      return value;
    }

    /// Checkpoint S: waits for [goalSummariesProvider] to emit a value
    /// satisfying [predicate], attaching the listener BEFORE the caller
    /// performs whatever write is expected to produce it -- same race
    /// avoidance as the "a soft-deleted goal disappears..." test above
    /// (the listener must be registered before the write, not after,
    /// since Drift's stream-invalidation notification can otherwise
    /// arrive before a listener attached only after the write settles).
    /// Checks the CURRENT value first so a call made after the write
    /// already landed doesn't hang waiting for a future emission that
    /// will never come.
    Future<AsyncValue<List<SavingsGoalSummary>>> waitForSummaries(
      ProviderContainer container,
      bool Function(List<SavingsGoalSummary>) predicate,
    ) async {
      final AsyncValue<List<SavingsGoalSummary>> current = container.read(goalSummariesProvider);
      if (current.hasValue && predicate(current.requireValue)) return current;

      final Completer<AsyncValue<List<SavingsGoalSummary>>> completer =
          Completer<AsyncValue<List<SavingsGoalSummary>>>();
      final ProviderSubscription<AsyncValue<List<SavingsGoalSummary>>> subscription = container
          .listen<AsyncValue<List<SavingsGoalSummary>>>(goalSummariesProvider, (previous, next) {
        if (next.hasValue && predicate(next.requireValue) && !completer.isCompleted) {
          completer.complete(next);
        }
      });
      try {
        return await completer.future;
      } finally {
        subscription.close();
      }
    }

    late AppDatabase db;
    late ProfileRepository profileRepo;
    late SavingsGoalRepository goalRepo;
    late SavingsGoalContributionRepository contributionRepo;
    late ProviderContainer container;

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<String> seedProfile() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      profileRepo = ProfileRepository(db);
      goalRepo = SavingsGoalRepository(db);
      contributionRepo = SavingsGoalContributionRepository(db, goalRepo);
      container = ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      return profileRepo.createProfile(
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
    }

    test('no goals -> an empty summaries list and an empty Home selection', () async {
      await seedProfile();
      await container.read(activeProfileProvider.future);

      final AsyncValue<List<SavingsGoalSummary>> result = await readSettledSummaries(container);
      expect(result.requireValue, isEmpty);

      final AsyncValue<GoalHomeSelection> selection = container.read(homeGoalSelectionProvider);
      expect(selection.requireValue.kind, GoalHomeSelectionKind.empty);
    });

    test('a goal with no contributions summarizes with saved == zero', () async {
      final String profileId = await seedProfile();
      await goalRepo.createGoal(
        profileId: profileId,
        name: 'Emergency Fund',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await container.read(activeProfileProvider.future);

      final AsyncValue<List<SavingsGoalSummary>> result = await readSettledSummaries(container);
      final List<SavingsGoalSummary> summaries = result.requireValue;
      expect(summaries, hasLength(1));
      expect(summaries.single.calculation.saved, Money.zero('JPY'));
      expect(summaries.single.calculation.status, SavingsGoalStatus.inProgress);
    });

    test('saved reflects the sum of active contributions', () async {
      final String profileId = await seedProfile();
      final String goalId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Emergency Fund',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(30000, 'JPY'));
      await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(20000, 'JPY'));
      await container.read(activeProfileProvider.future);

      final AsyncValue<List<SavingsGoalSummary>> result = await readSettledSummaries(container);
      expect(result.requireValue.single.calculation.saved, Money.fromMinorUnits(50000, 'JPY'));
    });

    test('a fully-funded goal is status completed with a zero recommended contribution', () async {
      final String profileId = await seedProfile();
      final String goalId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Emergency Fund',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        targetDate: DateTime.now().toUtc().add(const Duration(days: 30)),
      );
      await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(100000, 'JPY'));
      await container.read(activeProfileProvider.future);

      final AsyncValue<List<SavingsGoalSummary>> result = await readSettledSummaries(container);
      final SavingsGoalCalculation calc = result.requireValue.single.calculation;
      expect(calc.status, SavingsGoalStatus.completed);
      expect(calc.recommendedDailyContribution, Money.zero('JPY'));
    });

    test('a soft-deleted goal disappears from goalSummariesProvider and goalSummaryProvider',
        () async {
      final String profileId = await seedProfile();
      final String goalId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Temporary',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await container.read(activeProfileProvider.future);
      final AsyncValue<List<SavingsGoalSummary>> initial = await readSettledSummaries(container);
      expect(initial.requireValue, hasLength(1)); // still present before delete

      // The listener is attached BEFORE the soft-delete write, so no
      // emission can be missed to a race between the write's Future
      // completing and Drift's stream-invalidation notification
      // actually reaching this container (the same class of timing
      // issue `budget_providers_test.dart`'s doc comment describes --
      // `readSettledSummaries` alone only guards the FIRST settle from
      // `AsyncLoading`, not "wait for the next update after an already-
      // settled read").
      final Completer<AsyncValue<List<SavingsGoalSummary>>> afterDelete =
          Completer<AsyncValue<List<SavingsGoalSummary>>>();
      final ProviderSubscription<AsyncValue<List<SavingsGoalSummary>>> subscription = container
          .listen<AsyncValue<List<SavingsGoalSummary>>>(goalSummariesProvider, (previous, next) {
        if (next.hasValue && next.requireValue.isEmpty && !afterDelete.isCompleted) {
          afterDelete.complete(next);
        }
      });
      await goalRepo.softDeleteGoal(goalId);
      final AsyncValue<List<SavingsGoalSummary>> afterDeleteValue = await afterDelete.future;
      subscription.close();

      expect(afterDeleteValue.requireValue, isEmpty);

      final AsyncValue<SavingsGoalSummary?> byId = container.read(goalSummaryProvider(goalId));
      expect(byId.requireValue, isNull);
    });

    test('the Home selection picks the overdue goal over an inProgress one', () async {
      final String profileId = await seedProfile();
      final DateTime yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final DateTime nextMonth = DateTime.now().toUtc().add(const Duration(days: 30));

      await goalRepo.createGoal(
        profileId: profileId,
        name: 'On Track',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        targetDate: nextMonth,
      );
      final String overdueId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Overdue',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        targetDate: yesterday,
      );
      await container.read(activeProfileProvider.future);
      await readSettledSummaries(container);

      final AsyncValue<GoalHomeSelection> selection = container.read(homeGoalSelectionProvider);
      expect(selection.requireValue.kind, GoalHomeSelectionKind.priorityGoal);
      expect(selection.requireValue.summary!.id, overdueId);
    });

    test('goalCountProvider reflects the number of active goals', () async {
      final String profileId = await seedProfile();
      await goalRepo.createGoal(
        profileId: profileId,
        name: 'One',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await goalRepo.createGoal(
        profileId: profileId,
        name: 'Two',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await container.read(activeProfileProvider.future);
      await readSettledSummaries(container);

      final AsyncValue<int> count = container.read(goalCountProvider);
      expect(count.requireValue, 2);
    });

    test('goalContributionsProvider scopes to just the requested goal', () async {
      final String profileId = await seedProfile();
      final String goalAId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Goal A',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      final String goalBId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Goal B',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await contributionRepo.addContribution(goalId: goalAId, amount: Money.fromMinorUnits(1000, 'JPY'));
      await contributionRepo.addContribution(goalId: goalBId, amount: Money.fromMinorUnits(2000, 'JPY'));

      final List<SavingsGoalContributionRow> forA =
          await container.read(goalContributionsProvider(goalAId).future);
      expect(forA, hasLength(1));
      expect(forA.single.amountMinorUnits, 1000);
    });

    // -----------------------------------------------------------------
    // Checkpoint S: genuine gaps the audit found -- see
    // `docs/14_DECISION_LOG.md` ADR-042. None of these needed a
    // production fix (the derived-completion architecture already
    // produces the right answer); what was missing was regression
    // coverage actually proving it.
    // -----------------------------------------------------------------

    test(
      'deleting a contribution that completed a goal returns it to inProgress, since '
      'completion is always derived, never persisted (Section G/33)',
      () async {
        final String profileId = await seedProfile();
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final String contributionId = await contributionRepo.addContribution(
          goalId: goalId,
          amount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await container.read(activeProfileProvider.future);
        final SavingsGoalCalculation fundedCalc =
            (await readSettledSummaries(container)).requireValue.single.calculation;
        expect(fundedCalc.status, SavingsGoalStatus.completed);
        expect(fundedCalc.remaining, Money.zero('JPY'));

        final Future<AsyncValue<List<SavingsGoalSummary>>> pending = waitForSummaries(
          container,
          (summaries) => summaries.single.calculation.status == SavingsGoalStatus.inProgress,
        );
        await contributionRepo.softDeleteContribution(contributionId);
        final SavingsGoalCalculation afterDeleteCalc =
            (await pending).requireValue.single.calculation;

        expect(afterDeleteCalc.status, SavingsGoalStatus.inProgress);
        expect(afterDeleteCalc.saved, Money.zero('JPY'));
        expect(afterDeleteCalc.remaining, Money.fromMinorUnits(100000, 'JPY'));
      },
    );

    test(
      "lowering a goal's target below the already-contributed amount completes the goal, "
      'zeroes remaining, and leaves the contribution itself completely unchanged '
      '(Section D/17)',
      () async {
        final String profileId = await seedProfile();
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final String contributionId = await contributionRepo.addContribution(
          goalId: goalId,
          amount: Money.fromMinorUnits(90000, 'JPY'),
        );
        await container.read(activeProfileProvider.future);
        final SavingsGoalCalculation beforeCalc =
            (await readSettledSummaries(container)).requireValue.single.calculation;
        expect(beforeCalc.status, SavingsGoalStatus.inProgress);

        final Future<AsyncValue<List<SavingsGoalSummary>>> pending = waitForSummaries(
          container,
          (summaries) => summaries.single.calculation.status == SavingsGoalStatus.completed,
        );
        await goalRepo.updateGoal(id: goalId, targetAmount: Money.fromMinorUnits(50000, 'JPY'));
        final SavingsGoalCalculation afterCalc = (await pending).requireValue.single.calculation;

        expect(afterCalc.status, SavingsGoalStatus.completed);
        expect(afterCalc.remaining, Money.zero('JPY'));
        // The real contributed amount is preserved -- never clamped to
        // the new (lower) target, never refunded/fabricated away.
        expect(afterCalc.saved, Money.fromMinorUnits(90000, 'JPY'));
        // Uncapped, exactly matching the over-target formula (Section F).
        expect(afterCalc.wholePercentSaved, 180);

        final List<SavingsGoalContributionRow> contributions =
            await contributionRepo.watchActiveForGoal(goalId).first;
        expect(contributions, hasLength(1));
        expect(contributions.single.id, contributionId);
        expect(contributions.single.amountMinorUnits, 90000); // completely untouched
      },
    );

    test(
      "raising a completed goal's target back above its saved amount returns it to "
      'inProgress, since completion is derived rather than a separate persisted flag '
      '(Section D/18)',
      () async {
        final String profileId = await seedProfile();
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(50000, 'JPY'),
        );
        await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(50000, 'JPY'));
        await container.read(activeProfileProvider.future);
        final SavingsGoalCalculation beforeCalc =
            (await readSettledSummaries(container)).requireValue.single.calculation;
        expect(beforeCalc.status, SavingsGoalStatus.completed);

        final Future<AsyncValue<List<SavingsGoalSummary>>> pending = waitForSummaries(
          container,
          (summaries) => summaries.single.calculation.status == SavingsGoalStatus.inProgress,
        );
        await goalRepo.updateGoal(id: goalId, targetAmount: Money.fromMinorUnits(100000, 'JPY'));
        final SavingsGoalCalculation afterCalc = (await pending).requireValue.single.calculation;

        expect(afterCalc.status, SavingsGoalStatus.inProgress);
        expect(afterCalc.saved, Money.fromMinorUnits(50000, 'JPY')); // unchanged
        expect(afterCalc.remaining, Money.fromMinorUnits(50000, 'JPY'));
      },
    );
  });
}
