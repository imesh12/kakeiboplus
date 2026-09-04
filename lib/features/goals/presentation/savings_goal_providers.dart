import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../domain/savings_goal_calculation.dart';
import '../domain/savings_goal_status.dart';

/// One savings goal's row plus its fully-derived [SavingsGoalCalculation]
/// -- target/saved/remaining/status/pace/milestones, none of it
/// persisted (`docs/14_DECISION_LOG.md` ADR-022). This is the shape
/// every goals screen, and the Home priority selection below, actually
/// consume -- nothing downstream re-derives `saved` from a raw
/// contributions list itself.
@immutable
class SavingsGoalSummary {
  const SavingsGoalSummary({required this.goal, required this.calculation});

  final SavingsGoalRow goal;
  final SavingsGoalCalculation calculation;

  String get id => goal.id;
  String get name => goal.name;
}

/// All active goals for the current profile, reactively -- an empty list
/// (never "loading forever") once there's no active profile yet, same
/// convention `currentMonthBudgetsProvider` uses.
final StreamProvider<List<SavingsGoalRow>> _activeGoalRowsProvider =
    StreamProvider<List<SavingsGoalRow>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <SavingsGoalRow>[];
    return;
  }
  yield* ref.watch(savingsGoalRepositoryProvider).watchActiveGoals(profile.id);
});

/// Every active contribution across every one of the current profile's
/// currently-active goals, reactively.
///
/// Deliberately built by `asyncExpand`-ing off [_activeGoalRowsProvider]'s
/// own stream rather than a second independent query: whenever the
/// active goal set changes (a goal created or deleted),
/// `watchActiveForGoals` is re-subscribed against the new id set;
/// whenever a contribution changes for any goal in the CURRENT set, that
/// same subscription re-emits on its own. No SQL join and no rxdart
/// dependency -- just `Stream.asyncExpand`, which already cancels the
/// previous inner subscription for us each time the outer stream emits.
final StreamProvider<List<SavingsGoalContributionRow>> _activeContributionsProvider =
    StreamProvider<List<SavingsGoalContributionRow>>((ref) {
  return ref.watch(_activeGoalRowsProvider.stream).asyncExpand((goals) {
    final List<String> goalIds = goals.map((goal) => goal.id).toList(growable: false);
    return ref.watch(savingsGoalContributionRepositoryProvider).watchActiveForGoals(goalIds);
  });
});

/// Every active goal for the current profile, each with its calculated
/// [SavingsGoalCalculation] -- see [SavingsGoalSummary]. Re-derives
/// whenever either the goal list or any contribution changes, since both
/// are watched here; `todayUtc` is read once per re-derivation, the same
/// convention `livingCurrencyOverallBudgetProvider` uses for "now".
final Provider<AsyncValue<List<SavingsGoalSummary>>> goalSummariesProvider =
    Provider<AsyncValue<List<SavingsGoalSummary>>>((ref) {
  final AsyncValue<List<SavingsGoalRow>> goalsAsync = ref.watch(_activeGoalRowsProvider);
  final AsyncValue<List<SavingsGoalContributionRow>> contributionsAsync =
      ref.watch(_activeContributionsProvider);

  if (goalsAsync.isLoading || contributionsAsync.isLoading) {
    return const AsyncValue<List<SavingsGoalSummary>>.loading();
  }
  if (goalsAsync.hasError) {
    return AsyncValue<List<SavingsGoalSummary>>.error(goalsAsync.error!, goalsAsync.stackTrace!);
  }
  if (contributionsAsync.hasError) {
    return AsyncValue<List<SavingsGoalSummary>>.error(
      contributionsAsync.error!,
      contributionsAsync.stackTrace!,
    );
  }

  final List<SavingsGoalRow> goals = goalsAsync.requireValue;
  final List<SavingsGoalContributionRow> contributions = contributionsAsync.requireValue;
  final DateTime todayUtc = DateTime.now().toUtc();

  final List<SavingsGoalSummary> summaries = goals.map((goal) {
    final int savedMinorUnits = contributions
        .where((contribution) => contribution.goalId == goal.id)
        .fold<int>(0, (sum, contribution) => sum + contribution.amountMinorUnits);
    final SavingsGoalCalculation calculation = SavingsGoalCalculator.evaluate(
      target: Money.fromMinorUnits(goal.targetAmountMinorUnits, goal.currencyCode),
      saved: Money.fromMinorUnits(savedMinorUnits, goal.currencyCode),
      targetDateUtc: goal.targetDate,
      todayUtc: todayUtc,
    );
    return SavingsGoalSummary(goal: goal, calculation: calculation);
  }).toList(growable: false);

  return AsyncValue<List<SavingsGoalSummary>>.data(summaries);
});

/// Reactive count of active goals for the current profile -- what the
/// Profile entry point's subtitle shows.
final Provider<AsyncValue<int>> goalCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(goalSummariesProvider).whenData((summaries) => summaries.length);
});

/// One goal's [SavingsGoalSummary], reactively -- `null` if it doesn't
/// exist, or no longer does (e.g. it was soft-deleted while its detail
/// screen was open). Per `docs/14_DECISION_LOG.md` ADR-022, a
/// soft-deleted goal must resolve as unavailable here, never keep
/// showing stale data -- this is guaranteed because
/// [_activeGoalRowsProvider] (and therefore [goalSummariesProvider])
/// only ever contains active rows in the first place. Backed by
/// [goalSummariesProvider] rather than a fresh per-id query, so a goal's
/// detail screen and its Home/list entries are always derived from
/// exactly the same calculation.
final AutoDisposeProviderFamily<AsyncValue<SavingsGoalSummary?>, String> goalSummaryProvider =
    Provider.autoDispose.family<AsyncValue<SavingsGoalSummary?>, String>((ref, goalId) {
  return ref.watch(goalSummariesProvider).whenData((summaries) {
    for (final SavingsGoalSummary summary in summaries) {
      if (summary.id == goalId) return summary;
    }
    return null;
  });
});

/// Active (non-deleted) contribution history for one goal, newest first
/// -- what the goal detail screen's contribution list shows. Reads
/// straight from the repository (rather than [goalSummariesProvider]'s
/// aggregated list) since the detail screen needs individual rows, not
/// just the total.
final AutoDisposeStreamProviderFamily<List<SavingsGoalContributionRow>, String>
    goalContributionsProvider =
    StreamProvider.autoDispose.family<List<SavingsGoalContributionRow>, String>((ref, goalId) {
  return ref.watch(savingsGoalContributionRepositoryProvider).watchActiveForGoal(goalId);
});

/// What the Home dashboard's savings-goals card should show. Per
/// `docs/14_DECISION_LOG.md` ADR-022, there is no "most recently
/// completed goal" fallback (completion timestamps aren't persisted) --
/// when every goal is completed, [GoalHomeSelectionKind.allCompleted] is
/// the honest answer, not a guess.
enum GoalHomeSelectionKind {
  /// The profile has no goals at all yet.
  empty,

  /// The profile has goals, but every one of them is completed.
  allCompleted,

  /// [summary] is the highest-priority unfinished goal -- see
  /// [selectHomeGoalSummary].
  priorityGoal,
}

@immutable
class GoalHomeSelection {
  const GoalHomeSelection._({required this.kind, this.summary});

  static const GoalHomeSelection empty =
      GoalHomeSelection._(kind: GoalHomeSelectionKind.empty);
  static const GoalHomeSelection allCompleted =
      GoalHomeSelection._(kind: GoalHomeSelectionKind.allCompleted);

  factory GoalHomeSelection.priorityGoal(SavingsGoalSummary summary) =>
      GoalHomeSelection._(kind: GoalHomeSelectionKind.priorityGoal, summary: summary);

  final GoalHomeSelectionKind kind;

  /// Non-null exactly when [kind] is [GoalHomeSelectionKind.priorityGoal].
  final SavingsGoalSummary? summary;
}

/// Pure, non-Riverpod selection logic for the Home dashboard's
/// savings-goals card -- see `docs/14_DECISION_LOG.md` ADR-022. Kept as
/// a plain function (rather than inline inside a provider body) so it's
/// directly unit-testable without a `ProviderContainer`.
///
/// Priority order among unfinished (not [SavingsGoalStatus.completed])
/// goals:
///  1. [SavingsGoalStatus.overdue] before [SavingsGoalStatus.inProgress].
///  2. Within a status: sooner target date first; a goal with no target
///     date sorts after every goal that has one.
///  3. `createdAt` ascending as the final, deterministic tie-breaker.
///
/// A completed goal never competes with an unfinished one for this
/// selection -- if [summaries] is non-empty but every goal in it is
/// completed, the result is [GoalHomeSelection.allCompleted], never a
/// specific "most recently completed" pick (that would require a
/// completion timestamp this schema doesn't record).
GoalHomeSelection selectHomeGoalSummary(List<SavingsGoalSummary> summaries) {
  if (summaries.isEmpty) {
    return GoalHomeSelection.empty;
  }

  final List<SavingsGoalSummary> unfinished = summaries
      .where((summary) => summary.calculation.status != SavingsGoalStatus.completed)
      .toList();

  if (unfinished.isEmpty) {
    return GoalHomeSelection.allCompleted;
  }

  int statusRank(SavingsGoalStatus status) =>
      status == SavingsGoalStatus.overdue ? 0 : 1;

  unfinished.sort((a, b) {
    final int statusCompare =
        statusRank(a.calculation.status).compareTo(statusRank(b.calculation.status));
    if (statusCompare != 0) return statusCompare;

    final DateTime? aDate = a.goal.targetDate;
    final DateTime? bDate = b.goal.targetDate;
    if (aDate == null && bDate == null) {
      return a.goal.createdAt.compareTo(b.goal.createdAt);
    }
    if (aDate == null) return 1; // null target dates sort last
    if (bDate == null) return -1;
    final int dateCompare = aDate.compareTo(bDate);
    if (dateCompare != 0) return dateCompare;

    return a.goal.createdAt.compareTo(b.goal.createdAt);
  });

  return GoalHomeSelection.priorityGoal(unfinished.first);
}

/// The reactive [GoalHomeSelection] for the Home dashboard's
/// savings-goals card -- wraps [selectHomeGoalSummary] around
/// [goalSummariesProvider]'s current value.
final Provider<AsyncValue<GoalHomeSelection>> homeGoalSelectionProvider =
    Provider<AsyncValue<GoalHomeSelection>>((ref) {
  return ref.watch(goalSummariesProvider).whenData(selectHomeGoalSummary);
});
