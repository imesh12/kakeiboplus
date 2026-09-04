import 'package:meta/meta.dart';

/// A calendar month expressed as structured `year`/`month` fields --
/// never a floating "current month" concept and never a `YYYY-MM`
/// string parsed back apart. Every budget calculation in this feature is
/// anchored to one of these, so the same math works identically for the
/// current month, a historical month, or (structurally) a future one.
///
/// # Timezone convention
///
/// Like every other month-boundary calculation in the app today (see
/// `lib/features/dashboard/presentation/dashboard_providers.dart`), this
/// type is UTC-only. `Profile.timezone` is stored on the profile but is
/// not consumed by any computation anywhere in the app yet -- Beta 1
/// budgets deliberately does not invent a partial timezone-aware month
/// engine to be the first (and only) feature that honors it. A user
/// transacting near midnight UTC can see a transaction attributed to the
/// "wrong" local calendar day; this is a pre-existing, documented
/// limitation inherited unchanged from Beta 0, not something introduced
/// here. See `docs/14_DECISION_LOG.md` ADR-021.
///
/// # Year bounds
///
/// No other table in the schema constrains a year value, so this is a
/// new, first-of-its-kind convention introduced for the budgets feature
/// only: [year] must be between [minYear] and [maxYear] inclusive. That
/// range comfortably covers every real device clock this app will run
/// on and is generous enough that it will not need revisiting for
/// decades, while still rejecting an obviously corrupt value (e.g. year
/// 0, or a fat-fingered 20256) at the domain boundary rather than
/// persisting it.
@immutable
class BudgetMonth implements Comparable<BudgetMonth> {
  BudgetMonth({required this.year, required this.month}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be between 1 and 12');
    }
    if (year < minYear || year > maxYear) {
      throw ArgumentError.value(year, 'year', 'must be between $minYear and $maxYear');
    }
  }

  /// Builds the [BudgetMonth] containing [utcInstant], which must already
  /// be a UTC [DateTime] -- see the class doc's timezone convention.
  factory BudgetMonth.fromUtc(DateTime utcInstant) {
    assert(utcInstant.isUtc, 'BudgetMonth.fromUtc requires a UTC DateTime');
    return BudgetMonth(year: utcInstant.year, month: utcInstant.month);
  }

  static const int minYear = 2000;
  static const int maxYear = 2100;

  final int year;
  final int month;

  /// The first instant of this month, in UTC (inclusive).
  DateTime get startUtc => DateTime.utc(year, month);

  /// The last instant of this month, in UTC (inclusive) -- one
  /// microsecond before the next month starts. Matches the exact
  /// boundary convention `dashboard_providers.dart` already uses.
  DateTime get endUtcInclusive =>
      DateTime.utc(year, month + 1).subtract(const Duration(microseconds: 1));

  /// Total number of calendar days in this month (28-31), via the
  /// day-0-of-next-month trick -- correct for leap Februaries without a
  /// hand-written leap-year rule, and relies on the same `DateTime`
  /// month-overflow normalization `dashboard_providers.dart` already
  /// depends on for its own month-end boundary.
  int get totalDays => DateTime.utc(year, month + 1, 0).day;

  /// The calendar month immediately following this one (December rolls
  /// over into next January).
  BudgetMonth get next =>
      month == 12 ? BudgetMonth(year: year + 1, month: 1) : BudgetMonth(year: year, month: month + 1);

  /// The calendar month immediately before this one (January rolls back
  /// into last December).
  BudgetMonth get previous =>
      month == 1 ? BudgetMonth(year: year - 1, month: 12) : BudgetMonth(year: year, month: month - 1);

  @override
  int compareTo(BudgetMonth other) {
    if (year != other.year) return year.compareTo(other.year);
    return month.compareTo(other.month);
  }

  bool operator <(BudgetMonth other) => compareTo(other) < 0;
  bool operator <=(BudgetMonth other) => compareTo(other) <= 0;
  bool operator >(BudgetMonth other) => compareTo(other) > 0;
  bool operator >=(BudgetMonth other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetMonth && other.year == year && other.month == month);

  @override
  int get hashCode => Object.hash(year, month);

  /// `"YYYY-MM"` -- for logs, debugging, and provider keys only. Never
  /// persisted as a substitute for the structured `year`/`month` columns
  /// (see `docs/14_DECISION_LOG.md` ADR-021).
  String toKey() => '$year-${month.toString().padLeft(2, '0')}';

  @override
  String toString() => 'BudgetMonth(${toKey()})';
}
