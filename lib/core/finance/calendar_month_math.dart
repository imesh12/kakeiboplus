/// Calendar-safe, leap-year-aware, anchor-based month arithmetic.
///
/// This is the SAME algorithm `lib/features/recurring/domain
/// /recurring_schedule.dart` has used since Beta 1 Task 4A (ADR-023) for
/// its monthly/yearly occurrence math, extracted here so a second
/// calculation -- Checkpoint F's deposit maturity-date math (docs/20 §12.7
/// explicitly requires "reusing the project's existing calendar-safe,
/// leap-year-aware, anchor-based month/year arithmetic already
/// implemented for recurring rules ... not a second, independently
/// written calendar routine") -- calls the identical code rather than a
/// re-implementation that could silently drift from it over time.
/// `RecurringSchedule` itself is updated to call [addWholeCalendarMonths]
/// too, so there is now exactly one such routine in the codebase, not two
/// copies of the same logic.
///
/// # The rule
///
/// Adding N calendar months to an anchor date advances the month (and
/// rolls the year over normally), and clamps the anchor's *own*
/// day-of-month against the *target* month's actual length -- e.g. Jan 31
/// + 1 month = Feb 28 (or Feb 29 in a leap year), never Mar 3 (which is
/// what naively adding "30 days" would produce) and never Feb 31 (which
/// does not exist). Every call clamps independently against the
/// original anchor day -- see [addWholeCalendarMonths]'s own doc for why
/// that matters for a sequence of additions.
library;

/// The last day-of-month for [year]/[month] (1-12), leap-year aware --
/// e.g. `lastDayOfMonth(2026, 2) == 28`, `lastDayOfMonth(2028, 2) == 29`.
/// `DateTime.utc(year, month + 1, 0)` is the standard Dart idiom for "the
/// day before the 1st of next month" -- `DateTime` normalizes
/// `month + 1 == 13` into January of `year + 1` on its own, so this works
/// for December without a special case.
int lastDayOfMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Adds [months] whole calendar months to [anchorUtc], clamping the
/// result's day-of-month against the target month's actual length.
///
/// [anchorUtc] must already be a calendar-only UTC-midnight `DateTime`
/// (e.g. via `normalizeRecurringDate`) -- this function trusts its
/// caller, exactly as `RecurringSchedule` already does internally.
/// [months] must be `>= 0` -- every caller in this codebase only ever
/// advances forward in time (a deposit's maturity date is never before
/// its start date; a recurring rule's occurrences never run backward),
/// so there is no frozen "subtract months" convention to get wrong.
///
/// **Always measures from [anchorUtc] itself, never from a previously
/// clamped result.** A schedule anchored on Jan 31 must clamp Jan 31,
/// Feb 28/29, Mar 31, Apr 30, ... independently against each target
/// month's own length, always relative to the *original* Jan 31 -- not
/// by repeatedly adding one month to the last clamped result (which would
/// compute March from Feb 28 and drift to Mar 28 permanently, instead of
/// the correct Mar 31). Callers that need a *sequence* of monthly
/// additions (like `RecurringSchedule`) must call this once per
/// occurrence with the total month offset from the anchor, exactly as
/// `RecurringSchedule._occurrenceAt` does -- never by chaining
/// `addWholeCalendarMonths(addWholeCalendarMonths(anchor, 1), 1)`.
DateTime addWholeCalendarMonths(DateTime anchorUtc, int months) {
  assert(months >= 0, 'addWholeCalendarMonths only supports advancing forward in time');
  final int anchorMonthIndex = anchorUtc.year * 12 + (anchorUtc.month - 1);
  final int targetMonthIndex = anchorMonthIndex + months;
  final int targetYear = targetMonthIndex ~/ 12;
  final int targetMonth = targetMonthIndex % 12 + 1;
  final int lastDay = lastDayOfMonth(targetYear, targetMonth);
  final int day = anchorUtc.day > lastDay ? lastDay : anchorUtc.day;
  return DateTime.utc(targetYear, targetMonth, day);
}
