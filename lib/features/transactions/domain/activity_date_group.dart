import 'package:intl/intl.dart';

/// Beta 1 Transaction UX Phase B (`docs/14_DECISION_LOG.md` ADR-025/026) --
/// pure date-grouping helpers for the Activity screen's "Today" /
/// "Yesterday" / weekday / date section headers.
///
/// Deliberately pure and side-effect-free: nothing here ever calls
/// `DateTime.now()`. Both [ActivityDateGroup] and [groupByActivityDate]
/// take `now` as an explicit parameter, so grouping never depends on the
/// wall clock or the host's timezone -- the caller (the Activity screen
/// in production; a fixed fixture in tests) supplies it. Every
/// [DateTime] this file touches is expected to already be in LOCAL time
/// (e.g. `transaction.occurredAt.toLocal()`) -- this matches the
/// existing convention `activity_screen.dart` and ADR-025's Decision 3
/// already established, and this file does no UTC/local conversion of
/// its own.

/// Which bucket an [ActivityDateGroup] falls into. Exposed separately
/// from [ActivityDateGroup.label] so callers (and tests) can assert on
/// the bucket without depending on locale-formatted text, and so a
/// future styling hook (e.g. a different tint for "Today") has
/// something stable to switch on.
enum ActivityDateGroupKind { today, yesterday, thisWeek, thisYear, older }

/// One date-group's identity: a display [label] ('Today', 'Yesterday',
/// a weekday name, or a formatted date) plus a [dateKey] -- the local
/// calendar day it represents, normalized to local midnight.
///
/// [dateKey], not [label], is what [groupByActivityDate] uses to decide
/// whether two transactions belong to the same section. This matters:
/// [label] alone is not a unique key for "this week" or "older" groups
/// -- two transactions on different Mondays several weeks apart would
/// both render the label "Monday", and grouping by label text would
/// incorrectly merge them into one section.
class ActivityDateGroup {
  const ActivityDateGroup({required this.kind, required this.label, required this.dateKey});

  final ActivityDateGroupKind kind;
  final String label;
  final DateTime dateKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityDateGroup &&
          other.kind == kind &&
          other.label == label &&
          other.dateKey == dateKey);

  @override
  int get hashCode => Object.hash(kind, label, dateKey);

  @override
  String toString() => 'ActivityDateGroup(kind: $kind, label: $label, dateKey: $dateKey)';
}

/// One section of the grouped Activity list: a date [group] header plus
/// the (already-ordered) [items] that fall under it. Generic over [T] so
/// this stays decoupled from the Drift `Transaction` row type -- the
/// Activity screen supplies `Transaction`, tests can supply plain
/// fixture values.
class ActivityDateSection<T> {
  const ActivityDateSection({required this.group, required this.items});

  final ActivityDateGroup group;
  final List<T> items;
}

DateTime _localMidnight(DateTime localDateTime) =>
    DateTime(localDateTime.year, localDateTime.month, localDateTime.day);

/// Calendar-day difference between [nowLocal] and [occurredAtLocal],
/// both already local: positive means [occurredAtLocal] is in the past,
/// negative means it's in the future. Computed from calendar dates
/// (year/month/day), not elapsed [Duration] -- so a transaction at
/// 23:59 yesterday and one at 00:01 today are exactly 1 day apart here,
/// regardless of how few real-world minutes separate them, and the
/// result is immune to DST shifts within a day.
int _calendarDaysAgo({required DateTime occurredAtLocal, required DateTime nowLocal}) {
  final DateTime occurredDay = _localMidnight(occurredAtLocal);
  final DateTime today = _localMidnight(nowLocal);
  return today.difference(occurredDay).inDays;
}

/// The date-group a single local occurrence date/time falls into,
/// relative to [now] (also local -- see the library doc comment).
///
/// - Same calendar day as [now] -> "Today".
/// - Exactly one calendar day before [now] -> "Yesterday".
/// - 2-6 calendar days before [now] -> the weekday name (e.g. "Monday").
/// - Otherwise (7+ days before [now], OR a date on/after [now]'s day
///   that isn't today -- i.e. a future-dated transaction) -> a formatted
///   date: month/day only when [occurredAtLocal] falls in the same
///   calendar year as [now], otherwise month/day/year.
ActivityDateGroup activityDateGroupFor({required DateTime occurredAtLocal, required DateTime now}) {
  final DateTime dateKey = _localMidnight(occurredAtLocal);
  final int daysAgo = _calendarDaysAgo(occurredAtLocal: occurredAtLocal, nowLocal: now);

  if (daysAgo == 0) {
    return ActivityDateGroup(kind: ActivityDateGroupKind.today, label: 'Today', dateKey: dateKey);
  }
  if (daysAgo == 1) {
    return ActivityDateGroup(kind: ActivityDateGroupKind.yesterday, label: 'Yesterday', dateKey: dateKey);
  }
  if (daysAgo >= 2 && daysAgo <= 6) {
    return ActivityDateGroup(
      kind: ActivityDateGroupKind.thisWeek,
      label: DateFormat.EEEE().format(occurredAtLocal),
      dateKey: dateKey,
    );
  }
  final bool sameYear = occurredAtLocal.year == now.year;
  return ActivityDateGroup(
    kind: sameYear ? ActivityDateGroupKind.thisYear : ActivityDateGroupKind.older,
    label: sameYear ? DateFormat.MMMd().format(occurredAtLocal) : DateFormat.yMMMd().format(occurredAtLocal),
    dateKey: dateKey,
  );
}

/// Buckets [items] into ordered [ActivityDateSection]s by calendar day,
/// using [occurredAtLocalOf] to read each item's local occurrence date
/// and [activityDateGroupFor] to label it relative to [now].
///
/// [items] is expected to already be sorted newest-first (exactly what
/// `activeTransactionsProvider` already provides) -- this function does
/// a single linear pass merging consecutive same-day items into one
/// section; it does not itself sort or re-order [items]. Passing an
/// unsorted list will not corrupt data, but the same calendar day could
/// then appear as two separate non-adjacent sections instead of one.
List<ActivityDateSection<T>> groupByActivityDate<T>({
  required List<T> items,
  required DateTime Function(T item) occurredAtLocalOf,
  required DateTime now,
}) {
  final List<ActivityDateGroup> groups = <ActivityDateGroup>[];
  final List<List<T>> buckets = <List<T>>[];

  for (final T item in items) {
    final ActivityDateGroup group = activityDateGroupFor(occurredAtLocal: occurredAtLocalOf(item), now: now);
    if (groups.isNotEmpty && groups.last.dateKey == group.dateKey) {
      buckets.last.add(item);
    } else {
      groups.add(group);
      buckets.add(<T>[item]);
    }
  }

  return <ActivityDateSection<T>>[
    for (int i = 0; i < groups.length; i++)
      ActivityDateSection<T>(group: groups[i], items: List<T>.unmodifiable(buckets[i])),
  ];
}
