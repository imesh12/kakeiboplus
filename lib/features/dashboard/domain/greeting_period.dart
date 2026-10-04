/// Checkpoint U3 (docs/23_DASHBOARD_HEADER_BRAND_SPEC.md §4.2): the
/// Dashboard greeting's time-of-day discriminator.
///
/// Deliberately a plain, pure, Flutter-free enum with a pure static
/// resolver ([GreetingPeriod.forHour]) rather than a new time/clock
/// service -- docs/23 §4.2 itself asks not to "add a new heavy time
/// service solely for cosmetic greeting behavior," and `HomeScreen`
/// already has everything it needs (`DateTime.now()`, already local
/// device time) to compute an hour and hand it to this function. Kept
/// out of `home_screen.dart` specifically so the boundary logic itself
/// is unit-testable without pumping a widget tree.
enum GreetingPeriod {
  morning,
  afternoon,
  evening;

  /// Boundaries: [0, 12) -> morning, [12, 18) -> afternoon, [18, 24) ->
  /// evening -- ordinary, unsurprising local-clock buckets. [hour] is
  /// expected to be `DateTime.hour` (0-23); an out-of-range value
  /// clamps rather than throwing, since a mis-clamped greeting is
  /// cosmetic, never worth crashing the Dashboard over.
  static GreetingPeriod forHour(int hour) {
    if (hour < 12) return GreetingPeriod.morning;
    if (hour < 18) return GreetingPeriod.afternoon;
    return GreetingPeriod.evening;
  }
}
