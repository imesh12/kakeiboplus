import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../domain/recurrence_frequency.dart';
import '../domain/recurring_estimate.dart';
import '../domain/recurring_rule_kind.dart';
import '../domain/recurring_schedule.dart';
import 'recurring_providers.dart';

/// Checkpoint 11 -- Recurring + Subscriptions V1.
///
/// # Subscriptions are recurring-expense UX, not a second engine
///
/// There is deliberately no new Drift column, table, or accounting
/// concept here (see `docs/14_DECISION_LOG.md` ADR-031). A
/// "subscription" is simply an active (non-deleted --
/// [activeRecurringRulesProvider] already filters that),
/// `RecurringRuleKind.expense` recurring rule. Every provider in this
/// file is a pure, read-only VIEW derived from
/// `recurring_providers.dart`'s existing reactive data -- it never
/// writes, never introduces a parallel notion of "handled", and reuses
/// [RecurringPendingItem] (rather than a new subscription-specific type)
/// so the existing pending-item UI can be reused verbatim for the
/// Subscriptions tab.
bool isSubscriptionRule(RecurringRuleRow rule) =>
    RecurringRuleKind.values.byName(rule.kind) == RecurringRuleKind.expense;

/// Pure, non-Riverpod selection logic for the Subscriptions tab's list --
/// directly unit-testable without a `ProviderContainer`, same precedent
/// [selectHomeRecurringItem] established.
///
/// [items] is assumed already sorted the way
/// [recurringPendingItemsProvider] sorts it (overdue first, then today,
/// then nearest upcoming, and alphabetically by name within a tie).
/// This filters to subscription (expense) rules only, then keeps just
/// the FIRST item per rule id -- since a rule never contributes both an
/// unhandled overdue/due-today item and an upcoming preview at once
/// (see `_pendingItemsForRule`'s own doc comment), keeping the first
/// occurrence per rule id is exactly "one row per subscription, its
/// single most urgent pending date."
List<RecurringPendingItem> selectSubscriptionPendingItems(List<RecurringPendingItem> items) {
  final List<RecurringPendingItem> result = <RecurringPendingItem>[];
  final Set<String> seenRuleIds = <String>{};
  for (final RecurringPendingItem item in items) {
    if (!isSubscriptionRule(item.rule)) continue;
    if (!seenRuleIds.add(item.rule.id)) continue;
    result.add(item);
  }
  return result;
}

/// The reactive list of subscription rows for the Subscriptions tab, in
/// the exact same priority order [recurringPendingItemsProvider] already
/// establishes.
final Provider<AsyncValue<List<RecurringPendingItem>>> subscriptionPendingItemsProvider =
    Provider<AsyncValue<List<RecurringPendingItem>>>((ref) {
  return ref.watch(recurringPendingItemsProvider).whenData(selectSubscriptionPendingItems);
});

/// One currency's deterministic estimated subscription cost -- see
/// [computeSubscriptionEstimatedTotals]. Never combined with another
/// currency's totals into a single number (ADR-031): presenting
/// multiple [SubscriptionCurrencyTotal]s side by side, one per
/// currency, is the totals UI's job.
@immutable
class SubscriptionCurrencyTotal {
  const SubscriptionCurrencyTotal({
    required this.currencyCode,
    required this.monthlyEstimateMinorUnits,
    required this.yearlyEstimateMinorUnits,
    required this.subscriptionCount,
  });

  final String currencyCode;

  /// ROUND HALF UP sum, across every included rule in [currencyCode],
  /// of each rule's own independently-rounded
  /// [RecurringEstimate.monthlyMinorUnits] -- see that class's doc
  /// comment for why each rule's estimate is rounded once, on its own,
  /// before summation, rather than summing exact rationals first.
  final int monthlyEstimateMinorUnits;

  /// Same as [monthlyEstimateMinorUnits], but yearly -- and, per
  /// [RecurringEstimate], independently computed rather than derived
  /// from the monthly figure.
  final int yearlyEstimateMinorUnits;

  /// How many rules contributed to this currency's total -- shown so
  /// the totals UI can say e.g. "3 subscriptions in JPY" rather than
  /// just a bare amount.
  final int subscriptionCount;
}

/// Accumulator for [computeSubscriptionEstimatedTotals] -- private,
/// mutable, and never escapes that function; the public result is the
/// immutable [SubscriptionCurrencyTotal] list.
class _MutableCurrencyTotal {
  int monthlyMinorUnits = 0;
  int yearlyMinorUnits = 0;
  int subscriptionCount = 0;
}

/// Deterministic, integer-only estimated monthly/yearly subscription
/// cost, grouped separately by currency -- **never** summed across
/// currencies into one fabricated total, and never using a live/
/// reference FX rate to manufacture one either (ADR-031; the brief's
/// explicit "do not silently use live FX to manufacture a single
/// accounting total" rule).
///
/// [activeRules] should be [activeRecurringRulesProvider]'s current
/// value (every active, non-deleted rule for the profile -- already
/// excludes soft-deleted rules, so this function does not need to
/// re-check that). Included in the totals: every rule that is
/// [isSubscriptionRule] AND whose schedule has not already ended as of
/// [todayUtc] (`recurringScheduleOf(rule).occurrenceOnOrAfter(todayUtc)
/// == null` means the rule's last occurrence is already in the past --
/// same "ended" definition [RecurringSchedule] itself uses). This is
/// deliberately a BROADER set than
/// [selectSubscriptionPendingItems]/[subscriptionPendingItemsProvider]:
/// totals represent the whole steady-state recurring cost, not just
/// whatever happens to be due/overdue/next-upcoming right now.
///
/// The returned list is sorted by [SubscriptionCurrencyTotal.currencyCode]
/// for a deterministic, stable display order.
List<SubscriptionCurrencyTotal> computeSubscriptionEstimatedTotals({
  required List<RecurringRuleRow> activeRules,
  required DateTime todayUtc,
}) {
  final Map<String, _MutableCurrencyTotal> totalsByCurrency = <String, _MutableCurrencyTotal>{};

  for (final RecurringRuleRow rule in activeRules) {
    if (!isSubscriptionRule(rule)) continue;

    final RecurringSchedule schedule = recurringScheduleOf(rule);
    if (schedule.occurrenceOnOrAfter(todayUtc) == null) continue;

    final RecurringEstimate estimate = RecurringEstimate.of(
      frequency: RecurrenceFrequency.values.byName(rule.frequency),
      interval: rule.interval,
      amountMinorUnits: rule.amountMinorUnits,
    );

    final _MutableCurrencyTotal totals =
        totalsByCurrency.putIfAbsent(rule.currencyCode, () => _MutableCurrencyTotal());
    totals.monthlyMinorUnits += estimate.monthlyMinorUnits;
    totals.yearlyMinorUnits += estimate.yearlyMinorUnits;
    totals.subscriptionCount += 1;
  }

  final List<SubscriptionCurrencyTotal> result = totalsByCurrency.entries
      .map(
        (entry) => SubscriptionCurrencyTotal(
          currencyCode: entry.key,
          monthlyEstimateMinorUnits: entry.value.monthlyMinorUnits,
          yearlyEstimateMinorUnits: entry.value.yearlyMinorUnits,
          subscriptionCount: entry.value.subscriptionCount,
        ),
      )
      .toList(growable: false);
  result.sort((a, b) => a.currencyCode.compareTo(b.currencyCode));
  return result;
}

/// The reactive, per-currency [SubscriptionCurrencyTotal] list for the
/// Subscriptions tab's totals header.
final Provider<AsyncValue<List<SubscriptionCurrencyTotal>>> subscriptionEstimatedTotalsProvider =
    Provider<AsyncValue<List<SubscriptionCurrencyTotal>>>((ref) {
  final AsyncValue<List<RecurringRuleRow>> rulesAsync = ref.watch(activeRecurringRulesProvider);
  return rulesAsync.whenData(
    (rules) => computeSubscriptionEstimatedTotals(
      activeRules: rules,
      todayUtc: normalizeRecurringDate(DateTime.now().toUtc()),
    ),
  );
});
