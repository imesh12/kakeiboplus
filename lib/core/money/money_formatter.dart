import '../currency/currency.dart';
import 'money.dart';

/// Renders [Money] for display, always driven by [Currency.minorUnits] —
/// never by a hard-coded "currencies have two decimal places" assumption
/// or by a generic locale library's built-in per-currency defaults (KWD's
/// 3 minor units in particular is the kind of thing those are
/// inconsistent about). See `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §12.
///
/// The digits themselves are produced entirely from the exact integer
/// minor-units value ([Money.toMajorUnitsString]) — this formatter never
/// converts a [Money] to `double`, even transiently, so the "no double
/// for authoritative money" rule extends all the way to what the user
/// sees on screen, not just to storage/arithmetic.
///
/// Beta 0 scope note: grouping/decimal separator characters are the
/// plain ASCII `,` / `.` here rather than fully locale-driven (e.g.
/// swapping to `.` for grouping and `,` for the decimal point in
/// locales that use that convention). None of the Beta 0 release gates
/// depend on locale-specific separator swapping — see
/// `docs/09_TESTING_STRATEGY.md` and `docs/14_DECISION_LOG.md` — so this
/// is an intentional, documented scope trim rather than an oversight.
/// Swapping in full `intl`-driven separators is a small, contained
/// follow-up whenever locale-formatting work is prioritized (the
/// `preferred_language`/`number_format` profile fields already exist to
/// support it).
class MoneyFormatter {
  const MoneyFormatter({this.groupSeparator = ',', this.decimalSeparator = '.'});

  final String groupSeparator;
  final String decimalSeparator;

  /// Formats [money] as e.g. `"¥1,200"`, `"$12.34"`, `"KWD 1.235"`.
  String format(Money money) {
    final Currency currency = money.currency;
    final String exact = money.toMajorUnitsString(); // e.g. "-1234.56"
    final bool negative = exact.startsWith('-');
    final String unsigned = negative ? exact.substring(1) : exact;
    final int dotIndex = unsigned.indexOf('.');
    final String wholePart = dotIndex == -1 ? unsigned : unsigned.substring(0, dotIndex);
    final String fractionPart = dotIndex == -1 ? '' : unsigned.substring(dotIndex + 1);

    final String groupedWhole = _insertGroupSeparators(wholePart);

    final StringBuffer out = StringBuffer()
      ..write(negative ? '-' : '')
      ..write(currency.symbol)
      ..write(groupedWhole);
    if (fractionPart.isNotEmpty) {
      out
        ..write(decimalSeparator)
        ..write(fractionPart);
    }
    return out.toString();
  }

  /// Inserts [groupSeparator] every three digits from the right of
  /// [digits] (a non-negative whole-number digit string), e.g.
  /// `"1234567"` -> `"1,234,567"`. Pure string/integer manipulation —
  /// no floating point involved.
  String _insertGroupSeparators(String digits) {
    if (digits.length <= 3) return digits;
    final StringBuffer buffer = StringBuffer();
    final int firstGroupLength = digits.length % 3 == 0 ? 3 : digits.length % 3;
    buffer.write(digits.substring(0, firstGroupLength));
    for (int i = firstGroupLength; i < digits.length; i += 3) {
      buffer
        ..write(groupSeparator)
        ..write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }
}
