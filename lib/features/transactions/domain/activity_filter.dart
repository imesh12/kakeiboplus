import '../../../core/finance/transaction_type.dart';

/// Beta 1 Transaction UX Phase B (`docs/14_DECISION_LOG.md` ADR-025/026) --
/// pure, deterministic search/filter state and logic for the Activity
/// screen.
///
/// Deliberately has no dependency on Riverpod, Drift, or any widget --
/// this operates purely on values the caller has already resolved
/// (account/category names, a formatted amount string), so it is
/// trivially unit-testable and carries none of the "is this reactive/
/// wired up correctly" risk a provider would. The Activity screen wires
/// this to `activeTransactionsProvider` and to its own screen-local
/// filter state in a later checkpoint -- see `docs/14_DECISION_LOG.md`
/// ADR-026 point on locked product decisions: filter state is
/// screen-local (resets when leaving Activity), an empty [types] set
/// means "show all types" (never "show none"), and search is
/// case-insensitive deterministic substring matching only -- no fuzzy
/// matching, no ranking, no date-range filter, nothing persisted.

/// The Activity screen's filter/search state. Immutable -- callers
/// build a new instance via [copyWith] rather than mutating one in
/// place, matching this codebase's existing convention for small
/// value-shaped state (e.g. `RecurringSchedule`).
class ActivityFilterState {
  const ActivityFilterState({this.query = '', this.types = const <TransactionType>{}});

  /// The raw, not-yet-trimmed/lowercased search text as the user typed
  /// it -- [matchesActivityFilter] does the trimming/case-folding, so
  /// this field always reflects exactly what's in the search field.
  final String query;

  /// Which transaction types to show. **Empty means "show all types"**
  /// -- this is a locked product decision, not an accidental default --
  /// so an empty set must never be read as "show nothing".
  final Set<TransactionType> types;

  /// The default, no-filter-applied state -- what the Activity screen
  /// starts from every time it's opened (filter state is screen-local
  /// and does not persist across visits).
  static const ActivityFilterState initial = ActivityFilterState();

  /// Whether this state would narrow the transaction list at all. Lets
  /// callers skip filtering work entirely (and skip showing a "Clear
  /// filters" affordance) when nothing is actually active.
  bool get isActive => query.trim().isNotEmpty || types.isNotEmpty;

  ActivityFilterState copyWith({String? query, Set<TransactionType>? types}) => ActivityFilterState(
        query: query ?? this.query,
        types: types ?? this.types,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityFilterState &&
          other.query == query &&
          other.types.length == types.length &&
          other.types.containsAll(types));

  @override
  int get hashCode => Object.hash(query, Object.hashAllUnordered(types));

  @override
  String toString() => 'ActivityFilterState(query: $query, types: $types)';
}

/// Everything [matchesActivityFilter] needs to know about one
/// transaction, already resolved by the caller -- account/category id
/// lookups and the exact display string `MoneyFormatter` would render
/// for its amount -- so this file never touches a provider, the
/// database, or a formatter directly. Generic over [T] (the underlying
/// transaction/row type) purely so callers can get the matching item
/// back out; this file never inspects [item] itself.
class ActivitySearchable<T> {
  const ActivitySearchable({
    required this.item,
    required this.type,
    required this.accountName,
    required this.formattedAmount,
    this.categoryName,
    this.destinationAccountName,
    this.note,
  });

  final T item;
  final TransactionType type;

  /// The source account's name -- every transaction type has one.
  final String accountName;

  /// `MoneyFormatter.format(...)`'s exact output for this transaction's
  /// amount (without the +/-/none sign prefix the UI adds separately --
  /// see the locked search field list, "formatted amount").
  final String formattedAmount;

  /// Null for a transfer (transfers carry no category -- ADR-025
  /// Correction 2) or an expense/income with no category chosen.
  final String? categoryName;

  /// Null for anything other than a transfer.
  final String? destinationAccountName;

  final String? note;
}

/// Whether [row] matches [filter] -- true if [filter] isn't active at
/// all (nothing to narrow), otherwise the type filter (if any types are
/// selected) AND the search text (if any) must both match.
bool matchesActivityFilter<T>(ActivitySearchable<T> row, ActivityFilterState filter) {
  if (filter.types.isNotEmpty && !filter.types.contains(row.type)) return false;

  final String query = filter.query.trim().toLowerCase();
  if (query.isEmpty) return true;

  final List<String> haystacks = <String>[
    if (row.categoryName != null) row.categoryName!,
    row.accountName,
    if (row.destinationAccountName != null) row.destinationAccountName!,
    if (row.note != null) row.note!,
    row.formattedAmount,
  ];
  return haystacks.any((String haystack) => haystack.toLowerCase().contains(query));
}

/// Filters [rows] by [filter], preserving their existing order.
/// Deterministic substring matching only -- no fuzzy matching, no
/// ranking/reordering of results (a locked product decision).
List<ActivitySearchable<T>> filterActivity<T>(
  List<ActivitySearchable<T>> rows,
  ActivityFilterState filter,
) {
  if (!filter.isActive) return List<ActivitySearchable<T>>.unmodifiable(rows);
  return List<ActivitySearchable<T>>.unmodifiable(
    rows.where((ActivitySearchable<T> row) => matchesActivityFilter(row, filter)),
  );
}
