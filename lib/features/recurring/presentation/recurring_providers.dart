import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../domain/recurrence_frequency.dart';
import '../domain/recurring_schedule.dart';

/// How urgent a [RecurringPendingItem] is, relative to today's UTC
/// calendar date -- what the recurring screen's Overdue/Due
/// today/Upcoming sections are grouped by.
enum RecurringItemUrgency {
  /// `scheduledDateUtc` is strictly before today -- never handled
  /// (posted or skipped) yet.
  overdue,

  /// `scheduledDateUtc` is today -- never handled yet.
  dueToday,

  /// `scheduledDateUtc` is the rule's nearest occurrence strictly after
  /// today.
  upcoming,
}

/// One rule's scheduled date the recurring screen can act on: post it
/// (create a real transaction), or skip it. Never persisted itself --
/// see `RecurringOccurrenceRepository`; this is purely a derived,
/// in-memory view of "what's due", recomputed fresh every time from the
/// rule's schedule and its already-handled occurrences.
@immutable
class RecurringPendingItem {
  const RecurringPendingItem({
    required this.rule,
    required this.scheduledDateUtc,
    required this.urgency,
  });

  final RecurringRuleRow rule;
  final DateTime scheduledDateUtc;
  final RecurringItemUrgency urgency;
}

/// All active rules for the current profile, reactively -- an empty
/// list (never "loading forever") once there's no active profile yet,
/// same convention `_activeGoalRowsProvider` uses.
final StreamProvider<List<RecurringRuleRow>> activeRecurringRulesProvider =
    StreamProvider<List<RecurringRuleRow>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <RecurringRuleRow>[];
    return;
  }
  yield* ref.watch(recurringRuleRepositoryProvider).watchActiveRules(profile.id);
});

/// Every handled occurrence across every one of the current profile's
/// currently-active rules, reactively. Public (not `_`-prefixed) since
/// Beta 1 Task 4B's notification reconciliation
/// (`recurring_notification_providers.dart`) also watches this --
/// posting or skipping an occurrence must cancel its exact pending
/// reminder, so that layer needs the same handled-occurrence data this
/// screen's pending-items computation already does.
///
/// Watches [activeRecurringRulesProvider]'s VALUE (not its `.stream`) so
/// that Riverpod's own dependency graph re-subscribes to
/// `watchHandledForRules` with a fresh `ruleIds` list whenever the
/// active rule set changes (a rule created/deleted). An earlier version
/// composed this via `activeRecurringRulesProvider.stream.asyncExpand
/// (...)` -- that is a Dart `Stream.asyncExpand` misuse: `asyncExpand`
/// pauses its outer subscription while forwarding an inner stream and
/// only resumes once that inner stream *completes*
/// (see `sdk/lib/async/stream.dart`). `watchHandledForRules` is a live
/// Drift `.watch()` query that never completes, so the outer
/// subscription was paused forever after the first rule-list snapshot
/// -- a rule created afterward was silently never added to `ruleIds`.
/// See the "MANUAL TASK4A BUG FOUND" investigation for the full runtime
/// evidence that diagnosed this.
final StreamProvider<List<RecurringOccurrenceRow>> handledOccurrencesProvider =
    StreamProvider<List<RecurringOccurrenceRow>>((ref) {
  final List<RecurringRuleRow> rules =
      ref.watch(activeRecurringRulesProvider).valueOrNull ?? const <RecurringRuleRow>[];
  final List<String> ruleIds = rules.map((rule) => rule.id).toList(growable: false);
  return ref.watch(recurringOccurrenceRepositoryProvider).watchHandledForRules(ruleIds);
});

/// Builds the pure [RecurringSchedule] for [rule] from its persisted
/// frequency/interval/start/end fields. Public (this helper was
/// previously private to this file) because
/// `subscription_providers.dart`'s totals computation (Checkpoint 11
/// -- Recurring + Subscriptions V1) needs the exact same schedule
/// derivation this file's own pending-items computation already
/// uses, and duplicating this four-field mapping a second time would
/// risk the two ever silently diverging.
RecurringSchedule recurringScheduleOf(RecurringRuleRow rule) => RecurringSchedule(
      frequency: RecurrenceFrequency.values.byName(rule.frequency),
      interval: rule.interval,
      startDateUtc: rule.startDate,
      endDateUtc: rule.endDate,
    );

/// Defensive iteration cap for the "upcoming" forward-walk in
/// [_pendingItemsForRule] -- a second line of defense against a
/// never-ending schedule (`endDateUtc == null`) paired with a
/// pathological amount of already-handled future data, never the
/// walk's primary termination mechanism (a finite schedule's own
/// `endDateUtc` already guarantees that -- see [_pendingItemsForRule]'s
/// doc comment). Sized generously against the shortest supported
/// period (daily, `interval == 1`): 10,000 daily occurrences is over 27
/// years, far beyond any realistic amount of legitimate early
/// posting/skipping a real user would ever do, so this cap can only
/// ever discard truly pathological data, never a still-active rule
/// under normal use.
const int _kMaxUpcomingScanIterations = 10000;

/// Derives every [RecurringPendingItem] for [rule] as of [todayUtc],
/// given the set of [handledDates] (scheduled dates that already have a
/// posted/skipped `RecurringOccurrences` row for this rule).
///
/// **A rule contributes its unhandled overdue/due-today dates, OR (only
/// when it has none) a single upcoming preview -- never both at once.**
/// This is the same "prefer overdue, then today, then nearest upcoming"
/// priority the Home selection docs already describe, applied per rule
/// rather than only across rules: once a rule has something actionable
/// (unhandled and on/before today), showing ITS OWN next-month/next-week
/// preview alongside that unhandled item would render the same rule
/// twice (two cards with the same name/id, one genuinely due and one a
/// premature preview of a date that cannot even be posted yet) --
/// exactly the duplicate-rendering defect this comment replaces. Once
/// every due-or-overdue date for a rule is handled (posted or skipped),
/// that rule naturally falls through to the "upcoming" branch below on
/// the next recomputation.
///
/// Deliberately bounded, never an unbounded scan: the overdue/due-today
/// backlog only ever looks between the rule's own `startDate` and
/// `todayUtc` (`RecurringSchedule.occurrencesInRange`'s own bound). The
/// "upcoming" preview below is a forward WALK over
/// [RecurringSchedule.nextOccurrenceAfter] -- never new calendar/
/// recurrence arithmetic of its own -- because a rule's nearest
/// occurrence after today can itself already be handled (Post/Skip are
/// never blocked from acting on a future date early -- see
/// `RecurringOccurrenceRepository`), in which case the single-lookup
/// version of this method would silently drop a still-active rule from
/// the pending-items list entirely (see `docs/14_DECISION_LOG.md`
/// ADR-031 addendum / the CP11 Android QA investigation this fixes).
/// See [_kMaxUpcomingScanIterations] for why that walk is still bounded.
List<RecurringPendingItem> _pendingItemsForRule({
  required RecurringRuleRow rule,
  required Set<DateTime> handledDates,
  required DateTime todayUtc,
}) {
  final RecurringSchedule schedule = recurringScheduleOf(rule);
  final List<RecurringPendingItem> items = <RecurringPendingItem>[];

  final List<DateTime> dueOrOverdue = schedule.occurrencesInRange(
    fromUtc: rule.startDate,
    toUtc: todayUtc,
  );
  for (final DateTime date in dueOrOverdue) {
    if (handledDates.contains(date)) continue;
    items.add(
      RecurringPendingItem(
        rule: rule,
        scheduledDateUtc: date,
        urgency: date.isBefore(todayUtc) ? RecurringItemUrgency.overdue : RecurringItemUrgency.dueToday,
      ),
    );
  }

  // Only preview an upcoming date when this rule has nothing unhandled
  // on or before today -- see the class-level note above. Walk forward
  // through the schedule's own future occurrences (via
  // [RecurringSchedule.nextOccurrenceAfter] only -- never duplicating
  // its calendar/recurrence math) until the first one NOT already in
  // [handledDates] is found, or the schedule itself genuinely ends
  // (`nextOccurrenceAfter` returns `null`, which it does at or before
  // `endDateUtc` -- see that method's own doc comment): that `null` is
  // this loop's primary, domain-correct termination guarantee for any
  // finite schedule, independent of how many future occurrences were
  // handled early. [_kMaxUpcomingScanIterations] is only a secondary,
  // defensive cap for a never-ending schedule (`endDateUtc == null`,
  // where nothing else bounds the walk) against pathological data --
  // see its doc comment for why it is sized generously enough to never
  // discard a still-active rule under any realistic use.
  if (items.isEmpty) {
    DateTime cursor = todayUtc;
    for (int i = 0; i < _kMaxUpcomingScanIterations; i++) {
      final DateTime? candidate = schedule.nextOccurrenceAfter(cursor);
      if (candidate == null) break; // Schedule has genuinely ended.
      if (!handledDates.contains(candidate)) {
        items.add(
          RecurringPendingItem(
            rule: rule,
            scheduledDateUtc: candidate,
            urgency: RecurringItemUrgency.upcoming,
          ),
        );
        break;
      }
      cursor = candidate;
    }
  }

  return items;
}

int _urgencyRank(RecurringItemUrgency urgency) => switch (urgency) {
      RecurringItemUrgency.overdue => 0,
      RecurringItemUrgency.dueToday => 1,
      RecurringItemUrgency.upcoming => 2,
    };

/// Every [RecurringPendingItem] across every active rule for the current
/// profile, sorted overdue-soonest-missed first, then due-today, then
/// upcoming-soonest first -- exactly the "Overdue / Due today / Upcoming"
/// grouping the recurring screen renders, and the priority order the
/// Home summary picks its single nearest item from (see
/// [homeRecurringSelectionProvider]).
final Provider<AsyncValue<List<RecurringPendingItem>>> recurringPendingItemsProvider =
    Provider<AsyncValue<List<RecurringPendingItem>>>((ref) {
  final AsyncValue<List<RecurringRuleRow>> rulesAsync = ref.watch(activeRecurringRulesProvider);
  final AsyncValue<List<RecurringOccurrenceRow>> handledAsync = ref.watch(handledOccurrencesProvider);

  if (rulesAsync.isLoading || handledAsync.isLoading) {
    return const AsyncValue<List<RecurringPendingItem>>.loading();
  }
  if (rulesAsync.hasError) {
    return AsyncValue<List<RecurringPendingItem>>.error(rulesAsync.error!, rulesAsync.stackTrace!);
  }
  if (handledAsync.hasError) {
    return AsyncValue<List<RecurringPendingItem>>.error(
      handledAsync.error!,
      handledAsync.stackTrace!,
    );
  }

  final List<RecurringRuleRow> rules = rulesAsync.requireValue;
  final List<RecurringOccurrenceRow> handled = handledAsync.requireValue;
  final DateTime todayUtc = normalizeRecurringDate(DateTime.now().toUtc());

  final List<RecurringPendingItem> items = <RecurringPendingItem>[];
  for (final RecurringRuleRow rule in rules) {
    final Set<DateTime> handledDates = handled
        .where((occurrence) => occurrence.ruleId == rule.id)
        .map((occurrence) => occurrence.scheduledDate)
        .toSet();
    items.addAll(_pendingItemsForRule(rule: rule, handledDates: handledDates, todayUtc: todayUtc));
  }

  items.sort((a, b) {
    final int urgencyCompare = _urgencyRank(a.urgency).compareTo(_urgencyRank(b.urgency));
    if (urgencyCompare != 0) return urgencyCompare;
    final int dateCompare = a.scheduledDateUtc.compareTo(b.scheduledDateUtc);
    if (dateCompare != 0) return dateCompare;
    return a.rule.name.compareTo(b.rule.name);
  });

  return AsyncValue<List<RecurringPendingItem>>.data(items);
});

/// What the Home dashboard's recurring summary should show. Per Beta 1
/// Task 4A: never sums mixed currencies into a fabricated combined
/// total -- this only ever surfaces ONE item (the highest-priority one,
/// per [recurringPendingItemsProvider]'s own ordering), each in its own
/// currency, never combined with any other.
enum RecurringHomeSelectionKind {
  /// No active rule has anything overdue, due today, or upcoming to
  /// show (including: no active rules exist at all).
  empty,

  /// [item] is the highest-priority pending item -- overdue before due
  /// today before upcoming, soonest date first within each.
  item,
}

@immutable
class RecurringHomeSelection {
  const RecurringHomeSelection._({required this.kind, this.item});

  static const RecurringHomeSelection empty =
      RecurringHomeSelection._(kind: RecurringHomeSelectionKind.empty);

  factory RecurringHomeSelection.item(RecurringPendingItem item) =>
      RecurringHomeSelection._(kind: RecurringHomeSelectionKind.item, item: item);

  final RecurringHomeSelectionKind kind;

  /// Non-null exactly when [kind] is [RecurringHomeSelectionKind.item].
  final RecurringPendingItem? item;
}

/// Pure, non-Riverpod selection logic for the Home dashboard's recurring
/// summary -- directly unit-testable without a `ProviderContainer`, same
/// precedent `selectHomeGoalSummary` established. [items] is assumed
/// already sorted the way [recurringPendingItemsProvider] sorts it
/// (overdue first, then today, then nearest upcoming); this simply picks
/// the first one.
RecurringHomeSelection selectHomeRecurringItem(List<RecurringPendingItem> items) {
  if (items.isEmpty) return RecurringHomeSelection.empty;
  return RecurringHomeSelection.item(items.first);
}

/// The reactive [RecurringHomeSelection] for the Home dashboard's
/// recurring summary card.
final Provider<AsyncValue<RecurringHomeSelection>> homeRecurringSelectionProvider =
    Provider<AsyncValue<RecurringHomeSelection>>((ref) {
  return ref.watch(recurringPendingItemsProvider).whenData(selectHomeRecurringItem);
});
