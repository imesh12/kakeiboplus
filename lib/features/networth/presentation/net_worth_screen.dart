import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_section_header.dart';
import 'net_worth_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Checkpoint J (docs/20 §13.14): the dedicated Net Worth screen. Reached
/// ONLY via a deliberate tap on `MoreScreen`'s "Net Worth" row -- never
/// from Home, and Home shows no net-worth figure of any kind (see
/// `home_screen.dart`'s doc comment on why that line was removed). This
/// is the sole place in the app that shows the user's full net worth,
/// including deposit principal and liability balances -- a privacy
/// boundary implemented purely through navigation (there is no separate
/// "hide net worth" setting; the number simply does not exist anywhere
/// reachable without this deliberate extra step).
///
/// Purely a presentation layer over [netWorthSummariesProvider] -- every
/// figure shown here is [FinanceEngine.accountBalance]'s existing,
/// unchanged output; this screen computes nothing itself.
class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<NetWorthCurrencySummary>> summariesAsync =
        ref.watch(netWorthSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.netWorthTitle)),
      body: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text(l10n.couldNotLoadNetWorth('$e'))),
        data: (List<NetWorthCurrencySummary> summaries) {
          if (summaries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.netWorthEmptyMessage, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            key: const Key('netWorthList'),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(l10n.netWorthScreenSubtitle, style: context.appTypography.secondaryBody),
              const SizedBox(height: 16),
              for (final NetWorthCurrencySummary summary in summaries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _CurrencyNetWorthSection(summary: summary),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CurrencyNetWorthSection extends StatelessWidget {
  const _CurrencyNetWorthSection({required this.summary});
  final NetWorthCurrencySummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppTokens tokens = context.appTokens;
    final bool isNegative = summary.netWorth.isNegative;

    return AppCard(
      key: Key('netWorthCurrencyCard_${summary.currencyCode}'),
      bordered: true,
      softShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            summary.currencyCode,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (isNegative)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.south_rounded, color: colors.error, size: 20),
                ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppMoneyText(
                    _formatter.format(summary.netWorth),
                    key: const Key('netWorthTotal'),
                    emphasis: AppMoneyEmphasis.hero,
                    color: isNegative ? colors.error : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          Text(l10n.netWorthTotalLabel, style: context.appTypography.eyebrow),
          SizedBox(height: tokens.spacing.md),
          _TotalsRow(
            label: l10n.totalAssetsLabel,
            value: _formatter.format(summary.totalAssets),
          ),
          const SizedBox(height: 4),
          _TotalsRow(
            label: l10n.totalLiabilitiesLabel,
            value: _formatter.format(summary.totalLiabilities),
          ),
          SizedBox(height: tokens.spacing.md),
          AppSectionHeader(title: l10n.assetsSectionTitle, eyebrow: true),
          const SizedBox(height: 4),
          for (final NetWorthAccountLine line in summary.assetLines)
            _NetWorthAccountRow(line: line, l10n: l10n),
          if (summary.liabilityLines.isNotEmpty) ...<Widget>[
            SizedBox(height: tokens.spacing.md),
            AppSectionHeader(title: l10n.liabilitiesSectionTitle, eyebrow: true),
            const SizedBox(height: 4),
            for (final NetWorthAccountLine line in summary.liabilityLines)
              _NetWorthAccountRow(line: line, l10n: l10n),
          ],
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTypography.secondaryBody,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTypography.body?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// One account's row within an Assets or Liabilities list -- shows name,
/// balance, and, when applicable, a small "Deposit" and/or "Closed"
/// badge. Never applies liability-style negative-money coloring to a
/// liability's own line -- its balance is displayed exactly as
/// `FinanceEngine.accountBalance` returns it (a non-negative magnitude),
/// matching this app's existing convention that a liability's "amount
/// owed" is never itself rendered as a signed/negative figure (see
/// `FinanceEngine.accountBalance`'s own doc).
class _NetWorthAccountRow extends StatelessWidget {
  const _NetWorthAccountRow({required this.line, required this.l10n});
  final NetWorthAccountLine line;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      // Repair (net worth test structural finders): a stable per-account
      // key -- the account's own name/balance text can legitimately
      // repeat elsewhere on this screen (a totals row, the headline),
      // so tests need a reliable way to scope a search to exactly this
      // one row rather than matching text anywhere on the card.
      // Presentation-only; renders nothing new and changes no visible
      // behavior.
      key: Key('netWorthAccountRow_${line.accountId}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: <Widget>[
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTypography.body,
                ),
                if (line.isDeposit) _Badge(text: l10n.assetsDepositBadge, colors: colors),
                if (line.isClosed) _Badge(text: l10n.accountClosedLabel, colors: colors),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatter.format(line.balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTypography.body?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.colors});
  final String text;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: context.appTypography.caption?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }
}
