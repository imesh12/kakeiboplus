import 'package:meta/meta.dart';

import '../../../core/finance/calendar_month_math.dart';
import 'recurrence_frequency.dart';

/// Normalizes [input] to a calendar-only UTC-midnight `DateTime` --
/// reads [DateTime.year]/[DateTime.month]/[DateTime.day] directly off
/// whatever `DateTime` it's given (never `.toUtc()`/`.toLocal()`, which
/// convert an *instant* and can shift which calendar day it lands on --
/// see `lib/features/goals/domain/goal_target_date.dart`'s doc comment
/// for the identical reasoning `SavingsGoals.targetDate` already
/// established). A recurring rule's `startDate`/`endDate` and an
/// occurrence's `scheduledDate` are calendar dates, never instants --
/// `docs/14_DECISION_LOG.md` ADR-023.
DateTime normalizeRecurringDate(DateTime input) => DateTime.utc(input.year, input.month, input.day);

/// A recurring rule's schedule -- pure, deterministic, and entirely
/// independent of Drift/Riverpod/the database, per Beta 1 Task 4A's
/// "deterministic recurrence calculation in a pure domain layer"
/// requirement. [RecurringRuleRepository] is what maps a persisted
/// `RecurringRuleRow` to/from this shape.
///
/// # Anchor-based monthly/yearly math
///
/// Every occurrence is computed directly from [startDateUtc] -- never by
/// repeatedly adding one period to the *previous* occurrence. That
/// distinction matters specifically for monthly/yearly schedules whose
/// anchor day doesn't exist in every target month: a schedule anchored
/// on Jan 31 must generate Jan 31, Feb 28/29, Mar 31, Apr 30, ... --
/// clamped to each target month's actual last day, but always measured
/// from the *original* Jan 31 anchor. Computing March's occurrence by
/// adding one month to February's already-clamped Feb 28 would produce
/// Mar 28, and the schedule would drift to the 28th permanently. This
/// class instead computes the *k*-th occurrence's target month directly
/// from [startDateUtc]'s month plus `k * intervalInMonths`, and clamps
/// only [startDateUtc]'s own day-of-month against that target month's
/// length -- so every occurrence, however far from the anchor, clamps
/// independently against the same original day, never a previously
/// clamped one.
///
/// # Inclusivity
///
/// [startDateUtc] is inclusive -- it is always the first occurrence.
/// [endDateUtc], if set, is inclusive -- an occurrence exactly on
/// [endDateUtc] is still valid; the first occurrence strictly after it
/// does not exist (every method below returns `null` or stops there).
@immutable
class RecurringSchedule {
  /// [startDateUtc] and [endDateUtc], if given, must already be
  /// calendar-only UTC-midnight dates (see [normalizeRecurringDate]) --
  /// this class trusts its caller (the repository layer, which
  /// normalizes at the write boundary, mirroring
  /// `SavingsGoalRepository`'s `normalizeCalendarDateToUtc` precedent)
  /// rather than re-normalizing on every call.
  const RecurringSchedule({
    required this.frequency,
    required this.interval,
    required this.startDateUtc,
    this.endDateUtc,
  }) : assert(interval >= 1, 'interval must be >= 1');

  final RecurrenceFrequency frequency;

  /// Repeat every [interval] units of [frequency] -- e.g. `frequency:
  /// weekly, interval: 2` is "every 2 weeks". Always `>= 1`.
  final int interval;

  /// Inclusive -- always the first occurrence.
  final DateTime startDateUtc;

  /// Inclusive, if set -- the last calendar date an occurrence may fall
  /// on. `null` means the schedule never ends.
  final DateTime? endDateUtc;

  /// How many months forward the *k*-th occurrence's target month is
  /// from [startDateUtc]'s month, for monthly/yearly frequencies. Not
  /// meaningful for daily/weekly.
  int get _intervalInMonths => frequency == RecurrenceFrequency.yearly ? interval * 12 : interval;

  /// How many days forward the *k*-th occurrence is from [startDateUtc],
  /// for daily/weekly frequencies. Not meaningful for monthly/yearly.
  int get _intervalInDays => frequency == RecurrenceFrequency.weekly ? interval * 7 : interval;

  bool get _isMonthBased =>
      frequency == RecurrenceFrequency.monthly || frequency == RecurrenceFrequency.yearly;

  /// The *k*-th occurrence (`k >= 0`; `k == 0` is [startDateUtc]
  /// itself), ignoring [endDateUtc] entirely -- callers filter that
  /// separately. See the class doc comment for why this always measures
  /// from [startDateUtc], never from occurrence `k - 1`.
  DateTime _occurrenceAt(int k) {
    assert(k >= 0, 'k must be >= 0');
    if (_isMonthBased) {
      // Delegates to the shared `calendar_month_math.dart` routine --
      // see that file's doc for why this is now the ONE anchor-based
      // month-clamping implementation in the codebase (docs/20 §12.7),
      // rather than a second copy of the same logic. Behavior is
      // unchanged: this is the identical algorithm that used to live
      // inline here.
      final int monthsToAdd = k * _intervalInMonths;
      return addWholeCalendarMonths(startDateUtc, monthsToAdd);
    }
    return startDateUtc.add(Duration(days: k * _intervalInDays));
  }

  /// The smallest `k >= 0` such that `_occurrenceAt(k)` is on or after
  /// [targetUtc] (which must already be `>= startDateUtc` -- callers
  /// clamp that separately). For daily/weekly this is closed-form
  /// (fixed-length periods); for monthly/yearly it's an estimate from
  /// the month distance, adjusted by a small linear search to account
  /// for day-of-month clamping, which can shift an occurrence by at
  /// most a few days relative to the naive month-count estimate.
  int _kOnOrAfter(DateTime targetUtc) {
    if (!_isMonthBased) {
      final int diffDays = targetUtc.difference(startDateUtc).inDays;
      if (diffDays <= 0) return 0;
      return (diffDays / _intervalInDays).ceil();
    }
    final int anchorMonthIndex = startDateUtc.year * 12 + (startDateUtc.month - 1);
    final int targetMonthIndex = targetUtc.year * 12 + (targetUtc.month - 1);
    final int monthDiff = targetMonthIndex - anchorMonthIndex;
    int k = monthDiff <= 0 ? 0 : (monthDiff / _intervalInMonths).ceil();
    // The estimate can overshoot or undershoot by a step or two once
    // day-of-month clamping is accounted for -- walk to the exact
    // boundary. Both loops terminate in O(1) steps in practice (the
    // clamping effect is bounded by a handful of days, far smaller than
    // one full period).
    while (k > 0 && !_occurrenceAt(k - 1).isBefore(targetUtc)) {
      k--;
    }
    while (_occurrenceAt(k).isBefore(targetUtc)) {
      k++;
    }
    return k;
  }

  /// The first occurrence on or after [dateUtc], or `null` if that would
  /// fall after [endDateUtc]. If [dateUtc] is before [startDateUtc], this
  /// returns [startDateUtc] itself (still the first occurrence).
  DateTime? occurrenceOnOrAfter(DateTime dateUtc) {
    final DateTime target = normalizeRecurringDate(dateUtc);
    final DateTime effectiveTarget = target.isBefore(startDateUtc) ? startDateUtc : target;
    final DateTime occurrence = _occurrenceAt(_kOnOrAfter(effectiveTarget));
    final DateTime? end = endDateUtc;
    if (end != null && occurrence.isAfter(end)) return null;
    return occurrence;
  }

  /// The first occurrence strictly after [dateUtc], or `null` if none
  /// exists on or before [endDateUtc].
  DateTime? nextOccurrenceAfter(DateTime dateUtc) {
    final DateTime target = normalizeRecurringDate(dateUtc);
    return occurrenceOnOrAfter(target.add(const Duration(days: 1)));
  }

  /// Every occurrence in the inclusive range `[fromUtc, toUtc]` -- always
  /// a finite, bounded list (never unbounded generation), since it stops
  /// at `toUtc` (and, independently, at [endDateUtc] if that's sooner).
  /// Returns an empty list if `toUtc` is before `fromUtc`, or if no
  /// occurrence falls in the range at all.
  List<DateTime> occurrencesInRange({required DateTime fromUtc, required DateTime toUtc}) {
    final DateTime from = normalizeRecurringDate(fromUtc);
    final DateTime to = normalizeRecurringDate(toUtc);
    if (to.isBefore(from)) return const <DateTime>[];

    final List<DateTime> result = <DateTime>[];
    DateTime? current = occurrenceOnOrAfter(from);
    while (current != null && !current.isAfter(to)) {
      result.add(current);
      current = nextOccurrenceAfter(current);
    }
    return result;
  }
}
