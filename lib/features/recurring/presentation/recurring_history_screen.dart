import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../categories/domain/category_color.dart';
import '../../categories/presentation/category_identity_icon.dart';
import '../../categories/presentation/category_providers.dart';
import '../../services/presentation/service_icon_asset.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/recurring_occurrence_status.dart';
import '../domain/recurring_rule_kind.dart';
import 'recurring_icon_asset.dart';
import 'recurring_providers.dart';

const MoneyFormatter _historyFormatter = MoneyFormatter();

/// Recurring UI Upgrade + History Views checkpoint, Cases 1 & 2: one
/// screen class covering both the all-services year history (Case 1 --
/// no [ruleId], reached by tapping the Recurring screen's summary card)
/// and a single rule's own history (Case 2 -- [ruleId] set, reached
/// from that rule's row). A genuine pushed [GoRoute] screen (its own
/// `Scaffold`/`AppBar`), matching the app's existing detail-screen
/// pattern (`AccountDetailScreen`/`GoalDetailScreen`/`ChequeDetailScreen`
/// -- see `app_router.dart`), not a bottom sheet, since this is a
/// substantial, independently-scrollable secondary view.
///
/// # Data source -- what is real, and what is a known, documented gap
///
/// Beta 1 Task 4A's `RecurringOccurrences` table (see
/// `core/database/tables.dart`) is the ONLY persisted record of a
/// handled (posted or skipped) occurrence -- there is no separate
/// "history" concept to invent, and this screen never fabricates one.
/// Both cases read it through existing, already-tested repository
/// methods (`RecurringOccurrenceRepository.watchHandledForRule`/
/// `watchHandledForRules`), via the pre-existing
/// `handledOccurrencesProvider` (Case 1) and the new, equally thin
/// `ruleHandledOccurrencesProvider` family (Case 2) in
/// `recurring_providers.dart` -- neither required any repository
/// change.
///
/// Recurring History Final Corrections checkpoint: Case 1 reads
/// [allHandledOccurrencesProvider]/[allRecurringRulesProvider] --
/// both active AND soft-deleted rules' handled occurrences -- not the
/// active-only [handledOccurrencesProvider]/[activeRecurringRulesProvider]
/// pair the main Recurring screen's list/pending-items computation
/// still uses (and must keep using: a soft-deleted rule never belongs
/// back in that active list -- see `RecurringRuleRepository.softDelete`'s
/// own doc comment). A soft-deleted rule's `RecurringRuleRow` --
/// including its `name`/`serviceIdentityKey`/`categoryId`/`accountId`
/// -- is never mutated by `softDelete` (only `deletedAt`/`updatedAt`
/// change), so this screen's existing icon/name/amount rendering needs
/// no special-casing for a deleted rule's row: it already falls back
/// through the exact same service -> category -> kind precedence
/// [_HistoryItemIcon] always used, gracefully, if a referenced category
/// no longer resolves either. Case 2 is intentionally NOT widened the
/// same way: a user reaches it from an existing (therefore active) row
/// on the Recurring screen, so it stays scoped to
/// [activeRecurringRulesProvider] -- see that class's own routing
/// precedent; nothing here adds a deleted rule back into any list a
/// user can act on.
class RecurringHistoryScreen extends ConsumerWidget {
  const RecurringHistoryScreen({super.key, this.ruleId});

  /// `null` selects Case 1 (all services, current calendar year).
  /// Non-null selects Case 2 (one rule's full history).
  final String? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? id = ruleId;
    return id == null
        ? _AllServicesHistoryView(l10n: l10n)
        : _RuleHistoryView(ruleId: id, l10n: l10n);
  }
}

/// One handled occurrence, joined with the [RecurringRuleRow] it
/// belongs to -- purely a presentation-layer pairing, built fresh on
/// every watch, never persisted.
class _HistoryEntry {
  const _HistoryEntry({required this.occurrence, required this.rule});

  final RecurringOccurrenceRow occurrence;
  final RecurringRuleRow rule;
}

class _AllServicesHistoryView extends ConsumerWidget {
  const _AllServicesHistoryView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RecurringOccurrenceRow>> occurrencesAsync =
        ref.watch(allHandledOccurrencesProvider);
    final AsyncValue<List<RecurringRuleRow>> rulesAsync = ref.watch(allRecurringRulesProvider);
    final int currentYear = DateTime.now().toUtc().year;

    Widget body;
    if (occurrencesAsync.isLoading || rulesAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (occurrencesAsync.hasError) {
      body = Center(child: Text(l10n.couldNotLoadRecurringRules(occurrencesAsync.error.toString())));
    } else if (rulesAsync.hasError) {
      body = Center(child: Text(l10n.couldNotLoadRecurringRules(rulesAsync.error.toString())));
    } else {
      final Map<String, RecurringRuleRow> rulesById = <String, RecurringRuleRow>{
        for (final RecurringRuleRow rule in rulesAsync.requireValue) rule.id: rule,
      };
      final List<_HistoryEntry> entries = occurrencesAsync.requireValue
          .where((RecurringOccurrenceRow occurrence) =>
              occurrence.scheduledDate.toUtc().year == currentYear &&
              rulesById.containsKey(occurrence.ruleId))
          .map((RecurringOccurrenceRow occurrence) =>
              _HistoryEntry(occurrence: occurrence, rule: rulesById[occurrence.ruleId]!))
          .toList()
        ..sort((_HistoryEntry a, _HistoryEntry b) {
          final int byDate = b.occurrence.scheduledDate.compareTo(a.occurrence.scheduledDate);
          return byDate != 0 ? byDate : b.occurrence.handledAt.compareTo(a.occurrence.handledAt);
        });
      body = _HistoryList(entries: entries, l10n: l10n);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurringHistoryTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _RuleHistoryView extends ConsumerWidget {
  const _RuleHistoryView({required this.ruleId, required this.l10n});

  final String ruleId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RecurringOccurrenceRow>> occurrencesAsync =
        ref.watch(ruleHandledOccurrencesProvider(ruleId));
    final AsyncValue<List<RecurringRuleRow>> rulesAsync = ref.watch(activeRecurringRulesProvider);

    final RecurringRuleRow? rule = rulesAsync.valueOrNull
        ?.cast<RecurringRuleRow?>()
        .firstWhere((RecurringRuleRow? r) => r?.id == ruleId, orElse: () => null);

    Widget body;
    if (occurrencesAsync.isLoading || rulesAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (occurrencesAsync.hasError) {
      body = Center(child: Text(l10n.couldNotLoadRecurringRules(occurrencesAsync.error.toString())));
    } else if (rule == null) {
      // The rule this history belongs to is no longer active (deleted
      // mid-view, or reached with a stale id). `_HistoryEntry` always
      // pairs an occurrence with the rule it came from (every icon/
      // name lookup on the row depends on it), so there is nothing
      // honest to render per-row without one -- this falls back to the
      // same empty state Case 1 shows when there is genuinely no
      // history yet, rather than fabricating a placeholder rule. See
      // this screen class's own doc comment on the one documented
      // history-source gap (Case 1 has the identical limitation, for
      // the identical reason).
      body = _HistoryList(entries: const <_HistoryEntry>[], l10n: l10n);
    } else {
      final List<_HistoryEntry> entries = occurrencesAsync.requireValue
          .map((RecurringOccurrenceRow occurrence) => _HistoryEntry(occurrence: occurrence, rule: rule))
          .toList();
      body = _HistoryList(entries: entries, l10n: l10n);
    }

    return Scaffold(
      appBar: AppBar(title: Text(rule == null ? l10n.recurringHistoryTitle : l10n.recurringServiceHistoryTitle(rule.name))),
      body: SafeArea(child: body),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries, required this.l10n});

  final List<_HistoryEntry> entries;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.recurringHistoryEmptyMessage,
            textAlign: TextAlign.center,
            style: context.appTypography.caption,
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('recurringHistoryListView'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) =>
          _HistoryRow(entry: entries[index], key: Key('recurringHistoryRow_${entries[index].occurrence.id}')),
    );
  }
}

/// One history row: date, service/category icon, service/rule name,
/// value, and a small paid/skipped status indicator -- same content
/// shape for both Case 1 and Case 2.
class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry, super.key});

  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final RecurringOccurrenceRow occurrence = entry.occurrence;
    final RecurringRuleRow rule = entry.rule;
    final RecurringRuleKind kind = RecurringRuleKind.values.byName(rule.kind);
    final bool isTransferRule = kind == RecurringRuleKind.transfer;
    final bool isPosted = occurrence.status == RecurringOccurrenceStatus.posted.name;

    final AsyncValue<CategoryRow>? categoryAsync = (!isTransferRule && rule.categoryId != null)
        ? ref.watch(categoryByIdProvider(rule.categoryId!))
        : null;
    final CategoryRow? category = categoryAsync?.valueOrNull;

    // The authoritative amount for a POSTED occurrence is the real
    // `Transactions` row it created (never the rule's possibly-since-
    // edited current amount -- see this screen's class doc comment on
    // historical accuracy). A SKIPPED occurrence has no transaction at
    // all, so the rule's current configured amount is the closest real
    // data available for it, shown alongside an explicit "Skipped"
    // status so it is never mistaken for money that moved.
    final AsyncValue<Transaction?>? postedTransactionAsync =
        isPosted && occurrence.transactionId != null
            ? ref.watch(transactionByIdProvider(occurrence.transactionId!))
            : null;
    final Transaction? postedTransaction = postedTransactionAsync?.valueOrNull;
    final Money displayAmount = postedTransaction != null
        ? Money.fromMinorUnits(postedTransaction.amountMinorUnits, postedTransaction.currencyCode)
        : Money.fromMinorUnits(rule.amountMinorUnits, rule.currencyCode);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      bordered: true,
      // Recurring History Responsive Fix: the trailing amount/status
      // block below is deliberately unconstrained content that must
      // never be clipped (`AppMoneyText`'s own contract is that every
      // digit always renders; `AppStatusChip`'s own contract is a
      // one-line ellipsis, never an overflow) -- so on its own it isn't
      // protected from the classic Row-overflow failure mode: at 1.6x
      // text scale, `AppMoneyText`'s digits and `AppStatusChip`'s label
      // both grow, the icon does not, and nothing bounded the trailing
      // column's own width, so it could demand more room than this Row
      // had. Fixed with the exact technique `AppFinanceListRow` already
      // established for this identical shape (icon + Expanded title
      // column + unconstrained trailing block) -- see that widget's own
      // doc comment: a `LayoutBuilder` caps the trailing column to
      // whatever width the name/date column's `Expanded` would
      // otherwise be entitled to (the row's width minus the icon and
      // both spacers). At every normal width that cap sits above the
      // trailing block's natural size, so nothing about this row's
      // appearance changes; only when the row is genuinely too narrow
      // for both does the cap engage, and `AppMoneyText`/`AppStatusChip`
      // each fall back on their own built-in never-clip behavior (soft
      // wrap / ellipsis) instead of the Row overflowing.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double roomForTrailing =
              constraints.maxWidth - tokens.iconSizes.mediumContainer - tokens.spacing.sm * 2;
          final double maxTrailingWidth = roomForTrailing < 0 ? 0.0 : roomForTrailing;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _HistoryItemIcon(rule: rule, isTransferRule: isTransferRule, category: category),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      rule.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.yMMMd().format(occurrence.scheduledDate),
                      style: context.appTypography.caption,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppMoneyText(_historyFormatter.format(displayAmount), emphasis: AppMoneyEmphasis.primary),
                    const SizedBox(height: 4),
                    // Paid status icon: small, per the brief, using the
                    // approved `paid-bill-stamp.png` artwork. A skipped
                    // occurrence has no equivalent bundled artwork (only
                    // a "posted" stamp was provided in this icon pack),
                    // so it uses a small, muted Material glyph instead
                    // -- never the paid stamp, which would misrepresent
                    // it as money that moved. The status chip itself is
                    // wrapped in `Flexible` (the same pattern
                    // `home_screen.dart`'s own `AppStatusChip` call site
                    // already uses) so its own one-line-ellipsis
                    // contract can actually engage under the width cap
                    // above, rather than this small inner Row
                    // overflowing on its own.
                    isPosted
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Image.asset(
                                RecurringIconAssets.paidStamp,
                                width: 16,
                                height: 16,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                semanticLabel: l10n.recurringHistoryStatusPosted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: AppStatusChip(
                                  label: l10n.recurringHistoryStatusPosted,
                                  color: colors.primary,
                                  gradientColors: <Color>[
                                    colors.primary.withValues(alpha: 0.10),
                                    colors.primary.withValues(alpha: 0.20),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.block_outlined, size: 14, color: colors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: AppStatusChip(
                                  label: l10n.recurringHistoryStatusSkipped,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The same service > category > kind icon precedence
/// `_RecurringRuleRowState` already established on the Recurring
/// screen's own row, reproduced here (not extracted into a shared
/// widget) so this new, lower-risk screen never touches that existing,
/// already-tested row's code -- it calls the exact same centralized
/// resolvers (`serviceIconAssetFor`, [CategoryIdentityIcon]) those rows
/// call, so there is still a single source of truth for each
/// individual icon *lookup*, just not for this particular composition
/// of them.
class _HistoryItemIcon extends StatelessWidget {
  const _HistoryItemIcon({required this.rule, required this.isTransferRule, required this.category});

  final RecurringRuleRow rule;
  final bool isTransferRule;
  final CategoryRow? category;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final RecurringRuleKind kind = RecurringRuleKind.values.byName(rule.kind);
    final IconData kindIcon = switch (kind) {
      RecurringRuleKind.expense => Icons.trending_down_rounded,
      RecurringRuleKind.income => Icons.trending_up_rounded,
      RecurringRuleKind.transfer => Icons.swap_horiz_rounded,
    };
    final String? serviceAsset = isTransferRule ? null : serviceIconAssetFor(rule.serviceIdentityKey);
    final CategoryRow? category = this.category;
    final Color leadingColorValue = category != null
        ? categoryColorFor(categoryId: category.id, storedColorKey: category.colorKey, isDark: isDark)
        : colors.onSurfaceVariant;

    if (serviceAsset != null) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Image.asset(serviceAsset, width: 28, height: 28, fit: BoxFit.contain,
              filterQuality: FilterQuality.high, excludeFromSemantics: true),
        ),
      );
    }
    if (category != null) {
      return CategoryIdentityIcon(
        categoryId: category.id,
        iconKey: category.icon,
        colorKey: category.colorKey,
        size: AppIconTileSize.medium,
      );
    }
    return AppIconTile(icon: kindIcon, color: leadingColorValue, size: AppIconTileSize.medium);
  }
}
