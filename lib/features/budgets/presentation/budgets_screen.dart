import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_progress_bar.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../../categories/presentation/category_identity_icon.dart';
import '../../categories/presentation/category_providers.dart';
import '../domain/budget_month.dart';
import '../domain/budget_month_summary.dart';
import 'budget_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// The Beta 1 budget management screen: create/update/remove the
/// profile's overall monthly budget (per currency) and its category
/// budgets, for a **navigable** calendar month. Reached from the Profile
/// screen's "Budgets" entry and from the Home dashboard's budget card
/// call-to-action -- see `lib/core/routing/app_router.dart`.
///
/// Checkpoint Q (Monthly Budget Progress & Month Navigation):
/// [selectedBudgetMonthProvider] is the single source of truth for which
/// month this screen shows -- both which budgets are listed and how
/// much has been spent against them. It starts on the real current
/// month but the user may navigate away from it with the header
/// controls below; doing so never touches [currentBudgetMonthProvider]
/// (the separate, always-"now" month the Home dashboard's budget card
/// reads -- see that provider's own doc comment) and is never touched
/// by it either.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<BudgetRow>> budgetsAsync = ref.watch(budgetsForSelectedMonthProvider);
    final AsyncValue<List<BudgetMonthSummary>> summariesAsync = ref.watch(budgetMonthSummariesProvider);
    final BudgetMonth month = ref.watch(selectedBudgetMonthProvider);

    return Scaffold(
      // The "YYYY-MM" month key itself is left exactly as
      // `BudgetMonth.toKey()` already produces it -- see that method's
      // doc comment; only the surrounding "Budgets ·" word is
      // localized text. Tracks the *selected* month (not necessarily
      // "now") so the title never disagrees with the month the body
      // below is actually showing.
      appBar: AppBar(title: Text(l10n.budgetsScreenTitle(month.toKey()))),
      body: Column(
        children: <Widget>[
          // Checkpoint Q Section C: month navigation stays visible
          // regardless of loading/empty/error state below -- a month
          // with nothing in it is still a month the user can navigate
          // away from (Section L).
          _MonthNavigator(month: month),
          const Divider(height: 1),
          Expanded(
            child: budgetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) =>
                  Center(child: Text(l10n.couldNotLoadBudgets(e.toString()))),
              data: (List<BudgetRow> budgets) {
                final List<BudgetRow> overall =
                    budgets.where((BudgetRow b) => b.categoryId == null).toList();
                final List<BudgetRow> category =
                    budgets.where((BudgetRow b) => b.categoryId != null).toList();

                // Flattened budgetId -> CategoryBudgetProgress lookup so
                // each `_CategoryBudgetTile` can show its own spend/
                // remaining/percentage/progress bar without every tile
                // re-deriving the same arithmetic independently (Section
                // M). `summariesAsync` not yet settled (or errored) simply
                // means no progress numbers are shown yet -- the budget
                // list itself (from `budgetsAsync`, already settled here)
                // is never blocked on it.
                final Map<String, CategoryBudgetProgress> progressByBudgetId =
                    <String, CategoryBudgetProgress>{};
                for (final BudgetMonthSummary summary in summariesAsync.valueOrNull ?? const <BudgetMonthSummary>[]) {
                  for (final CategoryBudgetProgress p in summary.categoryProgress) {
                    progressByBudgetId[p.budgetId] = p;
                  }
                }

                if (budgets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.noBudgetsSetThisMonthMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: AppSectionHeader(title: l10n.monthSummarySectionTitle, eyebrow: true),
                    ),
                    _MonthSummarySection(summariesAsync: summariesAsync),
                    if (overall.isNotEmpty) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: AppSectionHeader(title: l10n.overallBudgetsSectionTitle, eyebrow: true),
                      ),
                      for (final BudgetRow row in overall) _OverallBudgetTile(row: row),
                    ],
                    if (category.isNotEmpty) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: AppSectionHeader(title: l10n.categoryBudgetsSectionTitle, eyebrow: true),
                      ),
                      for (final BudgetRow row in category)
                        _CategoryBudgetTile(row: row, progress: progressByBudgetId[row.id]),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addBudgetFab'),
        onPressed: () => _showAddBudgetSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddBudgetSheet(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                key: const Key('addOverallBudgetOption'),
                leading: const Icon(Icons.savings_outlined),
                title: Text(l10n.overallMonthlyBudgetOption),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showDialog<void>(context: context, builder: (_) => const _OverallBudgetDialog());
                },
              ),
              ListTile(
                key: const Key('addCategoryBudgetOption'),
                leading: const Icon(Icons.category_outlined),
                title: Text(l10n.categoryBudgetOption),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showDialog<void>(context: context, builder: (_) => const _CategoryBudgetDialog());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Checkpoint Q Section C: the "< August 2026 >"-style header. Arrows
/// only -- no `PageView`/swipe. This app has no existing swipe-driven
/// navigation pattern to extend, and the checkpoint brief is explicit
/// that a fragile infinite `PageView` merely to satisfy the word
/// "slide" is out of scope; correct prev/next navigation with proper
/// month-boundary math matters far more here than the gesture.
///
/// Both arrows write [selectedBudgetMonthProvider] -- the screen's one
/// and only month state -- via [BudgetMonth.previous]/[BudgetMonth.next],
/// which are already year-boundary-safe (December -> next -> January;
/// January -> previous -> last December) and never depend on
/// day-of-month. Never mutates any budget/transaction data; this widget
/// only changes which month is being *viewed*.
class _MonthNavigator extends ConsumerWidget {
  const _MonthNavigator({required this.month});

  final BudgetMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Locale-aware month/year text -- the same bare `DateFormat` (no
    // hard-coded month names, no explicit locale argument) convention
    // every other date display in this app already uses (see e.g.
    // `account_detail_screen.dart`'s `DateFormat.yMMMd()`), which tracks
    // whatever locale `MaterialApp.locale` (in turn `appLocaleProvider`,
    // driven by the profile's `preferredLanguage`) has already resolved
    // -- correct in both English and Japanese with no per-call-site
    // locale plumbing of its own.
    final String monthLabel = DateFormat.yMMM().format(DateTime.utc(month.year, month.month));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            key: const Key('previousMonthButton'),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.previousMonthTooltip,
            onPressed: () =>
                ref.read(selectedBudgetMonthProvider.notifier).state = month.previous,
          ),
          Expanded(
            child: Text(
              monthLabel,
              key: const Key('selectedMonthLabel'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTypography.sectionTitle,
            ),
          ),
          IconButton(
            key: const Key('nextMonthButton'),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.nextMonthTooltip,
            onPressed: () => ref.read(selectedBudgetMonthProvider.notifier).state = month.next,
          ),
        ],
      ),
    );
  }
}

/// Checkpoint Q Section D: one card per currency present in
/// [summariesAsync] (built only from category budgets -- never the
/// separate overall budget; see [BudgetMonthSummary]'s own doc comment
/// for why summing the two would double-count). Renders nothing while
/// still loading (the budget list above it already carries the
/// screen's own loading/error state; this section simply appears once
/// ready) and an explicit localized empty state -- never a fabricated
/// ¥0 card or stale numbers from a previously-viewed month -- when the
/// selected month has no category budgets at all (Section L).
class _MonthSummarySection extends StatelessWidget {
  const _MonthSummarySection({required this.summariesAsync});

  final AsyncValue<List<BudgetMonthSummary>> summariesAsync;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return summariesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (Object e, StackTrace st) => const SizedBox.shrink(),
      data: (List<BudgetMonthSummary> summaries) {
        if (summaries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              l10n.noCategoryBudgetsForMonthMessage,
              key: const Key('noCategoryBudgetsForMonthMessage'),
              style: context.appTypography.secondaryBody,
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (final BudgetMonthSummary summary in summaries) _MonthSummaryCard(summary: summary),
          ],
        );
      },
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.summary});

  final BudgetMonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool overBudget = summary.isOverBudget;
    // Checkpoint Q Section F: text is always the true, uncapped ratio
    // (e.g. "125% used" for a 1.25 ratio); only the progress bar's fill
    // fraction clamps to 1.0, because `LinearProgressIndicator` cannot
    // render past full. Section G: overspending is represented in words
    // ("¥2,500 over budget"), never a misleadingly-normal positive
    // "remaining" figure -- so the state is legible without relying on
    // color alone.
    final int percentUsed = (summary.usedRatio * 100).round();
    final Color barColor = overBudget ? colors.error : colors.primary;

    return AppCard(
      key: Key('monthSummaryCard_${summary.currencyCode}'),
      bordered: true,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(summary.currencyCode, style: context.appTypography.cardTitle),
              Flexible(
                child: Text(
                  l10n.percentUsedLabel('$percentUsed'),
                  key: Key('monthSummaryPercentUsed_${summary.currencyCode}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: context.appTypography.secondaryBody?.copyWith(
                    color: overBudget ? colors.error : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: l10n.totalBudgetLabel,
            value: _formatter.format(summary.totalBudget),
            valueKey: Key('monthSummaryTotalBudget_${summary.currencyCode}'),
          ),
          _StatRow(
            label: l10n.spentLabel,
            value: _formatter.format(summary.spent),
            valueKey: Key('monthSummarySpent_${summary.currencyCode}'),
          ),
          _StatRow(
            label: overBudget ? null : l10n.remainingLabel,
            value: overBudget
                ? l10n.overBudgetByAmountLabel(_formatter.format(summary.remaining.abs()))
                : _formatter.format(summary.remaining),
            valueKey: Key('monthSummaryRemaining_${summary.currencyCode}'),
            valueColor: overBudget ? colors.error : null,
          ),
          const SizedBox(height: 10),
          AppProgressBar(
            value: summary.usedRatio.clamp(0.0, 1.0),
            color: barColor,
            semanticLabel: l10n.percentUsedLabel('$percentUsed'),
          ),
        ],
      ),
    );
  }
}

/// A compact label/value pair, narrow-width-safe: [label] and [value]
/// each get a flexible share of the row so a longer translation or a
/// large formatted amount wraps/ellipsizes instead of overflowing --
/// same convention `_DetailRow` already establishes on
/// `goal_detail_screen.dart` for the same kind of row. [label] is
/// omitted entirely (only [value] renders, full-width) when the caller
/// has already folded the label into [value] itself -- see the
/// over-budget case on [_MonthSummaryCard] and [_CategoryBudgetTile],
/// where `l10n.overBudgetByAmountLabel(...)` already reads as a full
/// sentence fragment.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.value, this.label, this.valueKey, this.valueColor});

  final String? label;
  final String value;
  final Key? valueKey;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle? valueStyle = context.appTypography.secondaryBody?.copyWith(
      fontWeight: FontWeight.w600,
      color: valueColor,
    );
    if (label == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(value, key: valueKey, style: valueStyle),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(child: Text(label!, style: context.appTypography.secondaryBody)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, key: valueKey, style: valueStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _OverallBudgetTile extends ConsumerWidget {
  const _OverallBudgetTile({required this.row});
  final BudgetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Money amount = Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode);
    return AppCard(
      bordered: true,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        key: Key('overallBudgetTile_${row.currencyCode}'),
        leading: const Icon(Icons.savings_outlined),
        title: Text(row.currencyCode),
        subtitle: AppMoneyText(_formatter.format(amount), emphasis: AppMoneyEmphasis.secondary),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: Key('editOverallBudget_${row.currencyCode}'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTooltip,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _OverallBudgetDialog(existing: row),
              ),
            ),
            IconButton(
              key: Key('deleteOverallBudget_${row.currencyCode}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.removeTooltip,
              onPressed: () => unawaited(ref.read(budgetRepositoryProvider).softDelete(row.id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetTile extends ConsumerWidget {
  const _CategoryBudgetTile({required this.row, this.progress});
  final BudgetRow row;

  /// Checkpoint Q: this budget's evaluated spend/remaining/percentage
  /// for the selected month, from [budgetMonthSummariesProvider] --
  /// `null` only while that provider is still settling or has errored
  /// (the row itself, from [budgetsForSelectedMonthProvider], is shown
  /// either way; only the progress details are momentarily absent).
  final CategoryBudgetProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Money amount = Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode);
    final AsyncValue<CategoryRow> categoryAsync = ref.watch(categoryByIdProvider(row.categoryId!));
    final CategoryBudgetProgress? progress = this.progress;

    return AppCard(
      bordered: true,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              key: Key('categoryBudgetTile_${row.categoryId}_${row.currencyCode}'),
              // Checkpoint U1: was a fixed generic
              // `Icons.category_outlined` for every category budget
              // regardless of which category it tracked -- now the same
              // `CategoryIdentityIcon` every other category surface
              // renders through, so a budget tile visually matches its
              // category everywhere else it appears. Falls back to the
              // same pre-existing generic icon while [categoryAsync] is
              // still loading/has errored -- this tile's title text
              // already has its own loading/error fallback right below,
              // so the icon simply mirrors that rather than blocking on
              // it.
              leading: categoryAsync.when(
                data: (CategoryRow c) => CategoryIdentityIcon(
                  categoryId: c.id,
                  iconKey: c.icon,
                  colorKey: c.colorKey,
                  size: AppIconTileSize.small,
                ),
                loading: () => const Icon(Icons.category_outlined),
                error: (Object e, StackTrace st) => const Icon(Icons.category_outlined),
              ),
              title: Text(
                // `CategoryRow.name` is persisted content (a system category's
                // seeded English name, or a profile's own custom category) --
                // CP6.6 leaves it untouched exactly like every other screen
                // that already displays it (e.g. Activity). The loading
                // ellipsis and the categoryId fallback on error are not
                // translatable copy either -- a placeholder glyph and a raw
                // identifier, respectively.
                categoryAsync.when(
                  data: (CategoryRow c) => c.name,
                  loading: () => '…',
                  error: (Object e, StackTrace st) => row.categoryId!,
                ),
                style: context.appTypography.cardTitle,
                // CP7.9: a long custom category name would otherwise wrap next
                // to the trailing edit/delete icons -- ellipsize instead,
                // matching how every other long, user-entered name (e.g. the
                // account/category dropdown items) is already protected.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${row.currencyCode} · ${_formatter.format(amount)}',
                style: context.appTypography.secondaryBody?.copyWith(fontWeight: FontWeight.w600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    key: Key('editCategoryBudget_${row.id}'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.editTooltip,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _CategoryBudgetDialog(existing: row),
                    ),
                  ),
                  IconButton(
                    key: Key('deleteCategoryBudget_${row.id}'),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.removeTooltip,
                    onPressed: () => unawaited(ref.read(budgetRepositoryProvider).softDelete(row.id)),
                  ),
                ],
              ),
            ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _CategoryProgressDetails(progress: progress),
              ),
          ],
        ),
      ),
    );
  }
}

/// Checkpoint Q Section E/F/G: one category budget's spent/remaining/
/// percentage-used and progress bar, appended below its existing
/// `_CategoryBudgetTile` row rather than replacing any of that row's
/// existing content (name/amount/edit/delete all stay exactly as they
/// were).
class _CategoryProgressDetails extends StatelessWidget {
  const _CategoryProgressDetails({required this.progress});

  final CategoryBudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool overBudget = progress.isOverBudget;
    final int percentUsed = (progress.usedRatio * 100).round();
    final Color barColor = overBudget ? colors.error : colors.primary;
    final Money remaining = progress.calculation.remaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                // Same "spent of budgeted" idiom the dashboard's overall
                // budget card and the savings goal card already use
                // (`_AdaptiveAmountLine`'s `secondaryText: l10n.ofAmount(...)`
                // on `home_screen.dart`) -- e.g. "¥30,000 of ¥50,000".
                '${_formatter.format(progress.calculation.spent)} '
                '${l10n.ofAmount(_formatter.format(progress.calculation.budgeted))}',
                key: Key('categoryProgressSpentOfBudget_${progress.budgetId}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.secondaryBody,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.percentUsedLabel('$percentUsed'),
                key: Key('categoryProgressPercentUsed_${progress.budgetId}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: context.appTypography.secondaryBody?.copyWith(
                  color: overBudget ? colors.error : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppProgressBar(
          value: progress.usedRatio.clamp(0.0, 1.0),
          color: barColor,
          minHeight: 6,
          semanticLabel: l10n.percentUsedLabel('$percentUsed'),
        ),
        const SizedBox(height: 4),
        Text(
          overBudget
              ? l10n.overBudgetByAmountLabel(_formatter.format(remaining.abs()))
              : '${l10n.remainingLabel}: ${_formatter.format(remaining)}',
          key: Key('categoryProgressRemaining_${progress.budgetId}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.appTypography.secondaryBody?.copyWith(
            color: overBudget ? colors.error : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OverallBudgetDialog extends ConsumerStatefulWidget {
  const _OverallBudgetDialog({this.existing});
  final BudgetRow? existing;

  @override
  ConsumerState<_OverallBudgetDialog> createState() => _OverallBudgetDialogState();
}

class _OverallBudgetDialogState extends ConsumerState<_OverallBudgetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _currencyCode;
  Money? _parsedAmount;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final BudgetRow? existing = widget.existing;
    _currencyCode = existing?.currencyCode ?? CurrencyRegistry.seed.first.code;
    // Seed _parsedAmount directly from the existing row rather than
    // relying on the amount field's onChanged firing before Save is
    // pressed -- MoneyTextField only calls onParsed when its text
    // actually changes, so an edit dialog the user submits without
    // touching the (already-filled) amount field would otherwise never
    // populate this.
    if (existing != null) {
      _parsedAmount = Money.fromMinorUnits(existing.amountMinorUnits, existing.currencyCode);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final Money? amount = _parsedAmount;
    if (amount == null) return;
    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      // Checkpoint Q Section K: this dialog is always reached from a
      // Budgets screen currently showing `selectedBudgetMonthProvider`'s
      // month (whichever month that is -- current or historical) -- it
      // must create/update the budget for THAT month, never silently
      // fall back to the real current month. Reading
      // `currentBudgetMonthProvider` here (as this used to) would do
      // exactly that: viewing August and tapping "+" would silently
      // write a September budget while the screen still displayed
      // August's (unchanged) list.
      final BudgetMonth month = ref.read(selectedBudgetMonthProvider);
      await ref.read(budgetRepositoryProvider).setOverallBudget(
            profileId: profile.id,
            month: month,
            amount: amount,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? l10n.editOverallBudgetTitle : l10n.setOverallBudgetTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: InputDecoration(labelText: l10n.currencySection),
              // Fixed while editing -- changing currency would target a
              // different budget key instead of updating this one; to
              // budget a different currency, set a new overall budget.
              onChanged: editing ? null : (String? v) => setState(() => _currencyCode = v ?? _currencyCode),
              items: <DropdownMenuItem<String>>[
                for (final currency in CurrencyRegistry.seed)
                  DropdownMenuItem<String>(value: currency.code, child: Text(currency.code)),
              ],
            ),
            MoneyTextField(
              key: const Key('overallBudgetAmountField'),
              currencyCode: _currencyCode,
              label: l10n.monthlyBudgetAmountLabel,
              initialValue: widget.existing == null
                  ? null
                  : Money.fromMinorUnits(widget.existing!.amountMinorUnits, widget.existing!.currencyCode)
                      .toMajorUnitsString(),
              onParsed: (Money? m) => _parsedAmount = m,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('saveOverallBudget'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _CategoryBudgetDialog extends ConsumerStatefulWidget {
  const _CategoryBudgetDialog({this.existing});
  final BudgetRow? existing;

  @override
  ConsumerState<_CategoryBudgetDialog> createState() => _CategoryBudgetDialogState();
}

class _CategoryBudgetDialogState extends ConsumerState<_CategoryBudgetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _categoryId;
  late String _currencyCode;
  Money? _parsedAmount;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final BudgetRow? existing = widget.existing;
    _categoryId = existing?.categoryId;
    _currencyCode = existing?.currencyCode ?? CurrencyRegistry.seed.first.code;
    // Same reasoning as _OverallBudgetDialogState.initState.
    if (existing != null) {
      _parsedAmount = Money.fromMinorUnits(existing.amountMinorUnits, existing.currencyCode);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String? categoryId = _categoryId;
    final Money? amount = _parsedAmount;
    if (categoryId == null || amount == null) return;
    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      // Checkpoint Q Section K -- same reasoning as
      // `_OverallBudgetDialogState._submit` above: always the screen's
      // currently-selected month, never silently the real current month.
      final BudgetMonth month = ref.read(selectedBudgetMonthProvider);
      await ref.read(budgetRepositoryProvider).setCategoryBudget(
            profileId: profile.id,
            categoryId: categoryId,
            month: month,
            amount: amount,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool editing = widget.existing != null;
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider('expense'));

    return AlertDialog(
      title: Text(editing ? l10n.editCategoryBudgetTitle : l10n.setCategoryBudgetTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            categoriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
              error: (Object e, StackTrace st) => Text(l10n.couldNotLoadCategories(e.toString())),
              data: (List<CategoryRow> categories) {
                return DropdownButtonFormField<String>(
                  key: const Key('categoryBudgetCategoryField'),
                  initialValue: _categoryId,
                  decoration: InputDecoration(labelText: l10n.categoryFieldLabel),
                  // Fixed while editing -- see the currency-field comment
                  // in _OverallBudgetDialogState for the same reasoning.
                  onChanged: editing ? null : (String? v) => setState(() => _categoryId = v),
                  items: <DropdownMenuItem<String>>[
                    // `CategoryRow.name` is persisted content -- see the
                    // matching comment on `_CategoryBudgetTile` above;
                    // never translated here either.
                    for (final CategoryRow c in categories)
                      DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
                  ],
                  validator: (String? v) => v == null ? l10n.chooseCategoryMessage : null,
                );
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: InputDecoration(labelText: l10n.currencySection),
              onChanged: editing ? null : (String? v) => setState(() => _currencyCode = v ?? _currencyCode),
              items: <DropdownMenuItem<String>>[
                for (final currency in CurrencyRegistry.seed)
                  DropdownMenuItem<String>(value: currency.code, child: Text(currency.code)),
              ],
            ),
            MoneyTextField(
              key: const Key('categoryBudgetAmountField'),
              currencyCode: _currencyCode,
              label: l10n.categoryBudgetAmountLabel,
              initialValue: widget.existing == null
                  ? null
                  : Money.fromMinorUnits(widget.existing!.amountMinorUnits, widget.existing!.currencyCode)
                      .toMajorUnitsString(),
              onParsed: (Money? m) => _parsedAmount = m,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('saveCategoryBudget'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
