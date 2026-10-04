import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../../services/domain/service_identity_catalog.dart';
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

/// Recurring History Final Corrections checkpoint (Case 1 -- the
/// all-services year history): every rule for the current profile,
/// active AND soft-deleted alike, reactively. A thin wrapper around
/// the new, read-only `RecurringRuleRepository.watchAllRules` -- see
/// that method's own doc comment for why Case 1 needs it and every
/// active/upcoming-facing provider in this file (starting with
/// [activeRecurringRulesProvider] itself) deliberately does not.
final StreamProvider<List<RecurringRuleRow>> allRecurringRulesProvider =
    StreamProvider<List<RecurringRuleRow>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <RecurringRuleRow>[];
    return;
  }
  yield* ref.watch(recurringRuleRepositoryProvider).watchAllRules(profile.id);
});

/// Recurring History Final Corrections checkpoint (Case 1): every
/// handled occurrence across EVERY one of the current profile's rules
/// -- active AND soft-deleted alike -- reactively. The Case-1
/// counterpart to [handledOccurrencesProvider] above, which stays
/// exactly as it was (active rules only) for its own existing callers
/// (the pending-items computation, Beta 1 Task 4B's notification
/// reconciliation): this calls the SAME existing, already-tested
/// `RecurringOccurrenceRepository.watchHandledForRules` -- no
/// repository change, no new query -- just over [allRecurringRulesProvider]'s
/// wider rule-id list instead of [activeRecurringRulesProvider]'s. This
/// is what makes a soft-deleted rule's own already-handled occurrences
/// visible again in the all-services year history.
final StreamProvider<List<RecurringOccurrenceRow>> allHandledOccurrencesProvider =
    StreamProvider<List<RecurringOccurrenceRow>>((ref) {
  final List<RecurringRuleRow> rules =
      ref.watch(allRecurringRulesProvider).valueOrNull ?? const <RecurringRuleRow>[];
  final List<String> ruleIds = rules.map((rule) => rule.id).toList(growable: false);
  return ref.watch(recurringOccurrenceRepositoryProvider).watchHandledForRules(ruleIds);
});

/// Recurring UI Upgrade + History Views checkpoint (Case 2 -- one
/// service's own history view): every handled occurrence for a single
/// rule id, reactively, newest scheduled date first. A thin wrapper
/// around the existing, already-tested
/// `RecurringOccurrenceRepository.watchHandledForRule` -- no repository
/// change, no new query. Family-keyed by `ruleId` so the history
/// screen's own `ref.watch` re-subscribes cleanly per rule and disposes
/// when navigated away from (`.autoDispose`), matching
/// `transactionByIdProvider`'s own convention for a single-entity
/// detail screen.
final AutoDisposeStreamProviderFamily<List<RecurringOccurrenceRow>, String>
    ruleHandledOccurrencesProvider =
    StreamProvider.autoDispose.family<List<RecurringOccurrenceRow>, String>((ref, ruleId) {
  return ref.watch(recurringOccurrenceRepositoryProvider).watchHandledForRule(ruleId);
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

/// The normalized "today" UTC calendar date every recurring pending-item
/// computation reads -- extracted here (Checkpoint V, docs/14_DECISION_LOG.md
/// ADR-049) so [recurringPendingItemsProvider] and the new Home "Upcoming"
/// window selector below ([homeUpcomingItemsProvider]) always agree on
/// exactly the same instant within one provider rebuild, rather than each
/// calling `DateTime.now()` independently (which could theoretically
/// disagree across a midnight boundary). Pure extraction: the value and its
/// derivation (`normalizeRecurringDate(DateTime.now().toUtc())`) are
/// byte-for-byte unchanged from what [recurringPendingItemsProvider] always
/// computed inline before this pass.
final Provider<DateTime> recurringTodayUtcProvider = Provider<DateTime>((ref) {
  return normalizeRecurringDate(DateTime.now().toUtc());
});

/// Every [RecurringPendingItem] across every active rule for the current
/// profile, sorted overdue-soonest-missed first, then due-today, then
/// upcoming-soonest first -- exactly the "Overdue / Due today / Upcoming"
/// grouping the recurring screen renders, and the priority order the
/// Home summary picks its single nearest item from (see
/// [homeRecurringSelectionProvider]) and the Home "Upcoming" list windows
/// from (see [homeUpcomingItemsProvider]).
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
  final DateTime todayUtc = ref.watch(recurringTodayUtcProvider);

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

/// Checkpoint V (docs/14_DECISION_LOG.md ADR-049): Home's "Upcoming"
/// section window, in calendar days, for a future (`upcoming`-urgency)
/// item -- today through today + this many days, INCLUSIVE. Does not
/// affect `overdue`/`dueToday` items, which are never windowed (see
/// [selectHomeUpcomingItems]).
const int kHomeUpcomingWindowDays = 7;

/// Checkpoint V (ADR-049): the maximum number of rows Home's "Upcoming"
/// card ever shows, applied AFTER filtering/ordering -- see
/// [selectHomeUpcomingItems]'s own doc comment for why the cap must come
/// last.
const int kHomeUpcomingMaxRows = 3;

/// Pure, non-Riverpod selection logic for Home's compact multi-row
/// "Upcoming" list -- same directly-unit-testable precedent
/// [selectHomeRecurringItem]/`selectHomeGoalSummary` already established.
///
/// [items] is assumed already sorted the way
/// [recurringPendingItemsProvider] sorts it (overdue soonest-missed
/// first, then due-today, then nearest-upcoming first, with the
/// existing rule-name tie-break) -- this function reuses that order
/// verbatim via a single filter pass; it never re-sorts, re-derives
/// urgency, or re-implements overdue/handled-occurrence exclusion,
/// all of which stay exactly [recurringPendingItemsProvider]'s job.
///
/// Semantics (ADR-049):
///  1. Every `overdue` item passes the filter unconditionally -- an
///     overdue financial obligation must never disappear from Home to
///     make room for anything else.
///  2. Every `dueToday` item passes unconditionally.
///  3. An `upcoming` item passes only when its `scheduledDateUtc` falls
///     on or before `todayUtc + [kHomeUpcomingWindowDays]` days
///     (inclusive) -- i.e. "today through the next 7 calendar days,
///     inclusive," per ADR-049. `todayUtc` must be the SAME normalized
///     value [recurringPendingItemsProvider] computed [items] against
///     (see [recurringTodayUtcProvider]), never a second independent
///     `DateTime.now()` call, so this can never disagree with the
///     provider about what day it is.
///  4. The cap ([maxRows], default [kHomeUpcomingMaxRows]) is applied
///     LAST, after steps 1-3, over the already-correctly-ordered list.
///     If overdue items alone exceed the cap, they consume every
///     visible row -- overdue entries are never silently dropped to
///     make room for a future item; a future item is what yields, not
///     the other way around.
List<RecurringPendingItem> selectHomeUpcomingItems(
  List<RecurringPendingItem> items,
  DateTime todayUtc, {
  int maxRows = kHomeUpcomingMaxRows,
}) {
  final DateTime windowEndUtc = todayUtc.add(const Duration(days: kHomeUpcomingWindowDays));
  final List<RecurringPendingItem> windowed = items
      .where(
        (RecurringPendingItem item) =>
            item.urgency != RecurringItemUrgency.upcoming ||
            !item.scheduledDateUtc.isAfter(windowEndUtc),
      )
      .toList(growable: false);
  if (windowed.length <= maxRows) return windowed;
  return windowed.sublist(0, maxRows);
}

/// The reactive, capped "Upcoming" row list for Home's compact
/// multi-row card (ADR-049) -- additive alongside
/// [homeRecurringSelectionProvider], which stays exactly as it was for
/// its own existing callers/tests (see that provider's own doc comment
/// history). Reads the SAME [recurringPendingItemsProvider] output and
/// the SAME [recurringTodayUtcProvider] value
/// [recurringPendingItemsProvider] itself used to build [items] --
/// never a second, independently-derived "today."
final Provider<AsyncValue<List<RecurringPendingItem>>> homeUpcomingItemsProvider =
    Provider<AsyncValue<List<RecurringPendingItem>>>((ref) {
  final DateTime todayUtc = ref.watch(recurringTodayUtcProvider);
  return ref
      .watch(recurringPendingItemsProvider)
      .whenData((List<RecurringPendingItem> items) => selectHomeUpcomingItems(items, todayUtc));
});

/// Checkpoint R2 (Recurring screen redesign, docs/14_DECISION_LOG.md
/// ADR-TBD): one row's worth of data for the redesigned Recurring
/// screen's list -- **one entry per rule**, never per pending
/// occurrence date, unlike [RecurringPendingItem] (which the Recurring
/// screen used exclusively before this checkpoint, and which Home's
/// Upcoming card and the old Subscriptions tab still read directly,
/// unchanged). A rule with several unhandled overdue dates still
/// surfaces as exactly one [RecurringRuleSummary] row, carrying only
/// its SINGLE most urgent (oldest-overdue-first) [pendingItem] --
/// handling that one and refreshing naturally surfaces the next, same
/// "one row per rule, its single most urgent pending date" precedent
/// `subscription_providers.dart`'s [selectSubscriptionPendingItems]
/// already established and shipped (ADR-031) for the Subscriptions
/// tab, now generalized to every kind rather than expense-only.
@immutable
class RecurringRuleSummary {
  const RecurringRuleSummary({
    required this.rule,
    required this.nextOccurrenceUtc,
    required this.pendingItem,
  });

  final RecurringRuleRow rule;

  /// The schedule's own next occurrence on or after today -- computed
  /// directly from [RecurringSchedule.occurrenceOnOrAfter], completely
  /// independent of whether that date (or any other) has been posted
  /// or skipped. `null` means the rule's schedule has already ended as
  /// of today -- the EXACT "ended" definition
  /// `subscription_providers.dart`'s [computeSubscriptionEstimatedTotals]
  /// already uses, reused here rather than re-derived a second way.
  final DateTime? nextOccurrenceUtc;

  /// This rule's single most urgent unhandled [RecurringPendingItem],
  /// if it has one right now (overdue, due today, or its nearest
  /// upcoming preview) -- `null` only in the narrow edge case where a
  /// still-active rule's entire forward walk is exhausted by
  /// [_kMaxUpcomingScanIterations] (see that constant's doc comment:
  /// this can only ever happen for pathological data, never a
  /// realistic active rule). This is what the row's Post/Skip actions
  /// act on, and what [isUpcomingEligible] reads for the Upcoming
  /// filter.
  final RecurringPendingItem? pendingItem;

  /// The rule's schedule has not yet ended as of today -- see
  /// [nextOccurrenceUtc].
  bool get isActive => nextOccurrenceUtc != null;

  /// The rule's schedule has already ended as of today -- the Expired
  /// filter's exact definition (Checkpoint R2).
  bool get isExpired => nextOccurrenceUtc == null;
}

/// Pure, directly-unit-testable selector (same precedent every other
/// selector in this file established): builds one [RecurringRuleSummary]
/// per rule in [rules], using [pendingItems] (assumed already sorted
/// the way [recurringPendingItemsProvider] sorts it -- overdue
/// soonest-missed first, then due-today, then nearest-upcoming) to
/// find each rule's single most urgent pending item, if any. [rules]
/// is assumed to be every non-deleted rule for the profile (i.e.
/// [activeRecurringRulesProvider]'s current value) -- "active" there
/// means "not soft-deleted", never "schedule not yet ended"; THIS
/// function is what actually distinguishes active-schedule from
/// expired-schedule, via [RecurringRuleSummary.isActive]/[isExpired].
List<RecurringRuleSummary> selectRecurringRuleSummaries({
  required List<RecurringRuleRow> rules,
  required List<RecurringPendingItem> pendingItems,
  required DateTime todayUtc,
}) {
  final Map<String, RecurringPendingItem> firstPendingByRuleId = <String, RecurringPendingItem>{};
  for (final RecurringPendingItem item in pendingItems) {
    firstPendingByRuleId.putIfAbsent(item.rule.id, () => item);
  }
  return <RecurringRuleSummary>[
    for (final RecurringRuleRow rule in rules)
      RecurringRuleSummary(
        rule: rule,
        nextOccurrenceUtc: recurringScheduleOf(rule).occurrenceOnOrAfter(todayUtc),
        pendingItem: firstPendingByRuleId[rule.id],
      ),
  ];
}

/// Checkpoint R2: which of the redesigned Recurring screen's four
/// filter tabs is selected. Purely a presentation-layer selection
/// criterion over already-computed [RecurringRuleSummary] data -- see
/// [selectRecurringRuleSummariesForFilter] for the exact semantics of
/// each value, and `docs/14_DECISION_LOG.md` for the ADR recording why
/// these four (not e.g. a separate paused/disabled state, which this
/// domain has no field for at all -- every non-deleted rule is either
/// active or expired, nothing else).
enum RecurringListFilter { all, active, upcoming, expired }

/// Whether [summary]'s pending item (if any) falls inside the SAME
/// "due today or within [kHomeUpcomingWindowDays] days" window Home's
/// Upcoming card already uses (ADR-049) -- reused verbatim rather than
/// re-deriving a second "upcoming" definition, per this checkpoint's
/// own "prefer consistency with existing Home recurring date semantics"
/// instruction. An overdue item always counts (never windowed, same as
/// [selectHomeUpcomingItems]'s own overdue handling); a rule with no
/// pending item at all (the expired-with-everything-already-handled
/// case) never counts.
bool isUpcomingEligible(RecurringRuleSummary summary, DateTime todayUtc) {
  final RecurringPendingItem? item = summary.pendingItem;
  if (item == null) return false;
  if (item.urgency != RecurringItemUrgency.upcoming) return true;
  final DateTime windowEndUtc = todayUtc.add(const Duration(days: kHomeUpcomingWindowDays));
  return !item.scheduledDateUtc.isAfter(windowEndUtc);
}

/// Pure, directly-unit-testable selector: narrows [summaries] (assumed
/// already built by [selectRecurringRuleSummaries]) to exactly the
/// rows [filter] should show. Never re-sorts -- the input order (every
/// existing [recurringPendingItemsProvider]/[activeRecurringRulesProvider]
/// ordering guarantee) is preserved.
///
///  - [RecurringListFilter.all]: every rule visible to the profile,
///    subject to existing deletion semantics -- i.e. [summaries]
///    itself, unfiltered.
///  - [RecurringListFilter.active]: [RecurringRuleSummary.isActive].
///  - [RecurringListFilter.expired]: [RecurringRuleSummary.isExpired].
///  - [RecurringListFilter.upcoming]: [isUpcomingEligible].
List<RecurringRuleSummary> selectRecurringRuleSummariesForFilter(
  List<RecurringRuleSummary> summaries,
  RecurringListFilter filter,
  DateTime todayUtc,
) {
  switch (filter) {
    case RecurringListFilter.all:
      return summaries;
    case RecurringListFilter.active:
      return summaries.where((RecurringRuleSummary s) => s.isActive).toList(growable: false);
    case RecurringListFilter.expired:
      return summaries.where((RecurringRuleSummary s) => s.isExpired).toList(growable: false);
    case RecurringListFilter.upcoming:
      return summaries
          .where((RecurringRuleSummary s) => isUpcomingEligible(s, todayUtc))
          .toList(growable: false);
  }
}

/// Pure, directly-unit-testable, case-insensitive local search over
/// [summaries] -- Checkpoint R2's search box, combined with whichever
/// filter tab is active by applying this AFTER
/// [selectRecurringRuleSummariesForFilter] (never instead of it). Matches
/// against real, already-loaded text only: the rule's own [RecurringRuleRow
/// .name], its resolved service identity's real proper name (never a
/// locale-dependent generic family label -- [ServiceIdentityDefinition
/// .properName] is deliberately never localized, see that class's doc
/// comment, so this stays a pure function with no [AppLocalizations]
/// dependency), and its resolved category's real [CategoryRow.name] (via
/// [categoriesById], the same id->row map every other recurring-row
/// presentation code in this file's call sites already builds). Never
/// searches a nonexistent field. An empty/whitespace-only [query] matches
/// everything (search effectively off).
List<RecurringRuleSummary> searchRecurringRuleSummaries(
  List<RecurringRuleSummary> summaries,
  String query,
  Map<String, CategoryRow> categoriesById,
) {
  final String trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return summaries;
  return summaries.where((RecurringRuleSummary s) {
    final RecurringRuleRow rule = s.rule;
    if (rule.name.toLowerCase().contains(trimmed)) return true;
    final ServiceIdentityDefinition? service = serviceIdentityDefinitionFor(rule.serviceIdentityKey);
    final String? properName = service?.properName;
    if (properName != null && properName.toLowerCase().contains(trimmed)) return true;
    final CategoryRow? category = rule.categoryId == null ? null : categoriesById[rule.categoryId];
    if (category != null && category.name.toLowerCase().contains(trimmed)) return true;
    return false;
  }).toList(growable: false);
}

/// The reactive [RecurringRuleSummary] list for the redesigned
/// Recurring screen -- every non-deleted rule for the profile, each
/// paired with its own schedule-derived active/expired state and (if
/// any) its single most urgent pending item. Filtering by tab and
/// search query happens in the widget layer via
/// [selectRecurringRuleSummariesForFilter]/[searchRecurringRuleSummaries]
/// -- this provider always exposes the full, unfiltered set so the
/// four filter tabs' counts/content can never disagree about what
/// "every rule" means.
final Provider<AsyncValue<List<RecurringRuleSummary>>> recurringRuleSummariesProvider =
    Provider<AsyncValue<List<RecurringRuleSummary>>>((ref) {
  final AsyncValue<List<RecurringRuleRow>> rulesAsync = ref.watch(activeRecurringRulesProvider);
  final AsyncValue<List<RecurringPendingItem>> pendingAsync = ref.watch(recurringPendingItemsProvider);

  if (rulesAsync.isLoading || pendingAsync.isLoading) {
    return const AsyncValue<List<RecurringRuleSummary>>.loading();
  }
  if (rulesAsync.hasError) {
    return AsyncValue<List<RecurringRuleSummary>>.error(rulesAsync.error!, rulesAsync.stackTrace!);
  }
  if (pendingAsync.hasError) {
    return AsyncValue<List<RecurringRuleSummary>>.error(
      pendingAsync.error!,
      pendingAsync.stackTrace!,
    );
  }

  final DateTime todayUtc = ref.watch(recurringTodayUtcProvider);
  return AsyncValue<List<RecurringRuleSummary>>.data(
    selectRecurringRuleSummaries(
      rules: rulesAsync.requireValue,
      pendingItems: pendingAsync.requireValue,
      todayUtc: todayUtc,
    ),
  );
});

