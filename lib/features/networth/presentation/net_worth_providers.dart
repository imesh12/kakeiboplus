import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/account_repository.dart';
import '../../../core/finance/finance_engine.dart';
import '../../../core/finance/financial_account_subtype.dart';
import '../../../core/finance/ledger_models.dart';
import '../../../core/money/money.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// Checkpoint J: one account's contribution to its currency's net worth
/// breakdown, for the dedicated Net Worth screen -- the itemized detail
/// [dashboard_providers.dart]'s `CurrencyDashboardSummary` deliberately
/// never exposed (that type only ever carried the two ROLLED-UP figures
/// Home needs). Every field here is presentation-shaped metadata about
/// an account that already exists; nothing here computes a NEW balance
/// rule -- [balance] is always [FinanceEngine.accountBalance]'s result,
/// unchanged.
@immutable
class NetWorthAccountLine {
  const NetWorthAccountLine({
    required this.accountId,
    required this.name,
    required this.balance,
    required this.isLiability,
    required this.isDeposit,
    required this.isClosed,
  });

  final String accountId;
  final String name;

  /// Always a non-negative, class-native magnitude -- see
  /// `FinanceEngine.accountBalance`'s own doc. Never itself negative for
  /// a liability line.
  final Money balance;

  /// Whether this line belongs in the Liabilities section (subtracted
  /// from net worth) rather than Assets (added).
  final bool isLiability;

  /// Whether this is a deposit-subtype asset -- Net Worth screen labels
  /// these distinctly within Assets (docs/20 §13.14: deposits count as
  /// assets here, unlike Home's `availableBalance`, which excludes
  /// them).
  final bool isDeposit;

  /// Account Lifecycle: whether this account is closed
  /// (`AccountRow.deletedAt != null`). A closed account's balance still
  /// counts in the totals below -- see [NetWorthCurrencySummary]'s own
  /// doc -- this flag exists purely so the screen can show a quiet
  /// "Closed" badge next to the line, the same convention
  /// `AccountDetailScreen` already uses.
  final bool isClosed;
}

/// Checkpoint J: one currency's full net worth breakdown -- every
/// account this profile has ever owned in [currencyCode] (active or
/// closed), split into [assetLines]/[liabilityLines] plus the two
/// totals and their difference. [netWorth] here is computed the exact
/// same way `dashboard_providers.dart`'s `CurrencyDashboardSummary
/// .netWorth` is (asset balances added, liability balances subtracted,
/// closed accounts included, deposit principal included) -- this is a
/// presentation-layer breakdown of that same definition, not a second,
/// independently-derived figure that could drift from it.
@immutable
class NetWorthCurrencySummary {
  const NetWorthCurrencySummary({
    required this.currencyCode,
    required this.assetLines,
    required this.liabilityLines,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
  });

  final String currencyCode;
  final List<NetWorthAccountLine> assetLines;
  final List<NetWorthAccountLine> liabilityLines;

  /// Sum of every [assetLines] balance (deposits included) -- always
  /// `>= 0`.
  final Money totalAssets;

  /// Sum of every [liabilityLines] balance -- always `>= 0` (a
  /// liability's own balance is already a non-negative "amount owed"
  /// magnitude; this is the sum of those magnitudes, never a negative
  /// number).
  final Money totalLiabilities;

  /// `totalAssets - totalLiabilities`. May be negative (more owed than
  /// owned) -- this is the one figure on this screen allowed to be
  /// negative, and the UI marks that state visibly rather than hiding
  /// the sign.
  final Money netWorth;
}

/// Checkpoint J (docs/20 §13.14): the dedicated Net Worth screen's data
/// source -- one [NetWorthCurrencySummary] per currency the profile
/// holds money in, in the same living-currency-first display order
/// `dashboard_providers.dart`'s `dashboardCurrencySummariesProvider`
/// already uses (mirrored here rather than imported, since it's a
/// small pure ordering helper, not financial logic -- see
/// [_orderCurrencies] below).
///
/// Deliberately its OWN provider rather than a reuse/extension of
/// [dashboardCurrencySummariesProvider]: that provider's return type
/// only ever carries the two rolled-up figures Home needs
/// (`availableBalance`/`netWorth`), by design (Checkpoint I). Net Worth
/// needs the itemized per-account breakdown too, and this checkpoint's
/// own instruction is "remove the Net Worth line from Home... do not
/// undo the underlying Checkpoint-I net worth calculation" -- adding a
/// second, additive provider here satisfies that literally: nothing in
/// `dashboard_providers.dart` changes at all.
///
/// No FX conversion anywhere -- currencies are never combined; a user
/// holding both JPY and USD money sees two entirely independent
/// [NetWorthCurrencySummary] entries, each internally consistent, never
/// one blended figure (same ADR-017/Beta-0-has-no-FX-layer reasoning
/// `dashboardCurrencySummariesProvider`'s own doc already states).
final Provider<AsyncValue<List<NetWorthCurrencySummary>>> netWorthSummariesProvider =
    Provider<AsyncValue<List<NetWorthCurrencySummary>>>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(allAccountsProvider);
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);

  if (profileAsync.isLoading || accountsAsync.isLoading || ledgerAsync.isLoading) {
    return const AsyncValue<List<NetWorthCurrencySummary>>.loading();
  }
  if (profileAsync.hasError) {
    return AsyncValue<List<NetWorthCurrencySummary>>.error(
      profileAsync.error!,
      profileAsync.stackTrace!,
    );
  }
  if (accountsAsync.hasError) {
    return AsyncValue<List<NetWorthCurrencySummary>>.error(
      accountsAsync.error!,
      accountsAsync.stackTrace!,
    );
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<List<NetWorthCurrencySummary>>.error(
      ledgerAsync.error!,
      ledgerAsync.stackTrace!,
    );
  }

  final ProfileRow? profile = profileAsync.requireValue;
  if (profile == null) {
    return const AsyncValue<List<NetWorthCurrencySummary>>.loading(); // pre-onboarding
  }

  final List<AccountRow> accounts = accountsAsync.requireValue;
  if (accounts.isEmpty) {
    return const AsyncValue<List<NetWorthCurrencySummary>>.data(<NetWorthCurrencySummary>[]);
  }

  final List<LedgerTransaction> ledger = ledgerAsync.requireValue;
  final Set<String> currencyCodes = <String>{for (final AccountRow a in accounts) a.currencyCode};
  final List<String> orderedCurrencyCodes = _orderCurrencies(
    currencyCodes,
    livingCurrency: profile.livingCurrency,
    homeCurrency: profile.homeCurrency,
  );

  final List<NetWorthCurrencySummary> summaries = <NetWorthCurrencySummary>[
    for (final String currencyCode in orderedCurrencyCodes)
      _summaryForCurrency(currencyCode, accounts: accounts, ledger: ledger),
  ];

  return AsyncValue<List<NetWorthCurrencySummary>>.data(summaries);
});

NetWorthCurrencySummary _summaryForCurrency(
  String currencyCode, {
  required List<AccountRow> accounts,
  required List<LedgerTransaction> ledger,
}) {
  final List<NetWorthAccountLine> assetLines = <NetWorthAccountLine>[];
  final List<NetWorthAccountLine> liabilityLines = <NetWorthAccountLine>[];
  Money totalAssets = Money.zero(currencyCode);
  Money totalLiabilities = Money.zero(currencyCode);

  for (final AccountRow account in accounts) {
    if (account.currencyCode != currencyCode) continue;
    final Money balance = FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);
    final NetWorthAccountLine line = NetWorthAccountLine(
      accountId: account.id,
      name: account.name,
      balance: balance,
      isLiability: account.isLiability,
      isDeposit: account.subtypeValue == FinancialAccountSubtype.deposit,
      isClosed: account.deletedAt != null,
    );
    if (account.isLiability) {
      liabilityLines.add(line);
      totalLiabilities = totalLiabilities + balance;
    } else {
      assetLines.add(line);
      totalAssets = totalAssets + balance;
    }
  }

  return NetWorthCurrencySummary(
    currencyCode: currencyCode,
    assetLines: assetLines,
    liabilityLines: liabilityLines,
    totalAssets: totalAssets,
    totalLiabilities: totalLiabilities,
    netWorth: totalAssets - totalLiabilities,
  );
}

/// Byte-for-byte the same ordering `dashboard_providers.dart`'s private
/// `_orderCurrencies` implements -- living currency first, then home
/// currency if held and different, then everything else alphabetically.
/// Duplicated (not imported/shared) because it is a tiny, pure display-
/// ordering helper with zero financial meaning, not a rule this
/// checkpoint's "do not touch FinanceEngine/Checkpoint-I calculation"
/// constraint applies to -- keeping this file self-contained avoids
/// exporting a previously-private symbol from `dashboard_providers.dart`
/// just for this.
List<String> _orderCurrencies(
  Set<String> currencyCodes, {
  required String livingCurrency,
  required String homeCurrency,
}) {
  final List<String> ordered = <String>[];
  if (currencyCodes.contains(livingCurrency)) {
    ordered.add(livingCurrency);
  }
  if (homeCurrency != livingCurrency && currencyCodes.contains(homeCurrency)) {
    ordered.add(homeCurrency);
  }
  final List<String> rest = currencyCodes.where((String c) => !ordered.contains(c)).toList()
    ..sort();
  ordered.addAll(rest);
  return ordered;
}
