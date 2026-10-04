import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_swipe_action_row.dart';
import '../../../shared/widgets/app_circular_progress.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_progress_bar.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/currency_badge.dart';
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
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  String? _openBudgetId;

  void _closeRow() {
    if (_openBudgetId != null) setState(() => _openBudgetId = null);
  }

  Future<void> _confirmDelete(BudgetRow row) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(l10n.deleteBudgetConfirmTitle),
      content: Text(l10n.deleteBudgetConfirmMessage),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(key: const Key('confirmDeleteBudget'),
          onPressed: () => Navigator.pop(context, true), child: Text(l10n.removeTooltip)),
      ],
    ));
    if (confirmed == true && mounted) {
      await ref.read(budgetRepositoryProvider).softDelete(row.id);
    }
  }

  Widget _managedRow(BudgetRow row, Widget child) {
    final l10n = AppLocalizations.of(context);
    void edit() => showDialog<void>(context: context, builder: (_) => row.categoryId == null
        ? _OverallBudgetDialog(existing: row) : _CategoryBudgetDialog(existing: row));
    void remove() => unawaited(_confirmDelete(row));
    return KeyedSubtree(key: ValueKey(row.id), child: AppSwipeActionRow(
      isOpen: _openBudgetId == row.id,
      onOpenRequested: () => setState(() => _openBudgetId = row.id),
      onCloseRequested: _closeRow,
      onInteractionStart: () { if (_openBudgetId != row.id) _closeRow(); },
      onEdit: edit, onDelete: remove,
      editLabel: l10n.editTooltip, deleteLabel: l10n.removeTooltip,
      editActionKey: Key(row.categoryId == null ? 'editOverallBudget_${row.currencyCode}' : 'editCategoryBudget_${row.id}'),
      deleteActionKey: Key(row.categoryId == null ? 'deleteOverallBudget_${row.currencyCode}' : 'deleteCategoryBudget_${row.id}'),
      margin: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Semantics(key: Key('budgetActions_${row.id}'), container: true,
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.editTooltip): edit,
          CustomSemanticsAction(label: l10n.removeTooltip): remove,
        }, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final budgetsAsync = ref.watch(budgetsForSelectedMonthProvider);
    final summariesAsync = ref.watch(budgetMonthSummariesProvider);
    final month = ref.watch(selectedBudgetMonthProvider);
    ref.listen(selectedBudgetMonthProvider, (_, next) => _closeRow());
    Widget stateBody(Widget child) => Column(children: [
      _MonthNavigator(month: month), Expanded(child: Center(child: child)),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetsTitle)),
      body: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _closeRow,
        child: budgetsAsync.when(
          loading: () => stateBody(const CircularProgressIndicator()),
          error: (e, st) => stateBody(Text(l10n.couldNotLoadBudgets(e.toString()))),
          data: (budgets) {
            if (budgets.isEmpty) { return stateBody(Padding(padding: const EdgeInsets.all(24),
              child: Text(l10n.noBudgetsSetThisMonthMessage, textAlign: TextAlign.center))); }
            final overall = budgets.where((b) => b.categoryId == null);
            final category = budgets.where((b) => b.categoryId != null);
            final progress = <String, CategoryBudgetProgress>{
              for (final summary in summariesAsync.valueOrNull ?? <BudgetMonthSummary>[])
                for (final item in summary.categoryProgress) item.budgetId: item,
            };
            return ListView(padding: const EdgeInsets.only(top: 8, bottom: 88), children: [
              AppCard(bordered: true, softShadow: true, margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(12), child: Column(children: [
                  _MonthNavigator(month: month), const Divider(height: 1),
                  _MonthSummarySection(summariesAsync: summariesAsync),
                ])),
              if (overall.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: AppSectionHeader(title: l10n.overallBudgetsSectionTitle)),
                for (final row in overall) _managedRow(row, _OverallBudgetTile(row: row)),
              ],
              if (category.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: AppSectionHeader(title: l10n.categoryBudgetsSectionTitle)),
                for (final row in category) _managedRow(row, _CategoryBudgetTile(row: row, progress: progress[row.id])),
              ],
            ]);
          },
        )),
      floatingActionButton: FloatingActionButton(key: const Key('addBudgetFab'),
        onPressed: () => _showAddBudgetSheet(context), child: const Icon(Icons.add)),
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
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final tokens = context.appTokens;
    // Zero is not persisted by the repository. Keep a defensive display guard.
    final ratio = summary.totalBudget.minorUnits > 0 ? summary.usedRatio : 0.0;
    final percent = (ratio * 100).round();
    final over = summary.isOverBudget;
    final gradient = over ? tokens.colors.negativeGradient : tokens.colors.positiveGradient;
    Widget stat(String label, String value, String key, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.appTypography.caption?.copyWith(fontWeight: FontWeight.w600)),
        Text(value, key: Key(key), style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700, color: color)),
      ]),
    );
    final values = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(summary.currencyCode, style: context.appTypography.caption),
      stat(l10n.totalBudgetLabel, _formatter.format(summary.totalBudget), 'monthSummaryTotalBudget_${summary.currencyCode}'),
      stat(l10n.spentLabel, _formatter.format(summary.spent), 'monthSummarySpent_${summary.currencyCode}',
        color: over ? colors.error : null),
      stat(l10n.remainingLabel, over
        ? l10n.overBudgetByAmountLabel(_formatter.format(summary.remaining.abs()))
        : _formatter.format(summary.remaining), 'monthSummaryRemaining_${summary.currencyCode}',
        color: over ? colors.error : tokens.colors.positive),
    ]);
    final ring = AppCircularProgress(value: ratio,
      gradientColors: gradient ?? [over ? colors.error : colors.primary, over ? colors.error : colors.primary],
      semanticLabel: l10n.percentUsedLabel('$percent'),
      child: Text('$percent%', key: Key('monthSummaryPercentUsed_${summary.currencyCode}'),
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700,
          color: over ? colors.error : colors.onSurface)),
    );
    return Padding(key: Key('monthSummaryCard_${summary.currencyCode}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 300 && MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: ring), const SizedBox(height: 12), values]);
        }
        return Row(children: [ring, const SizedBox(width: 20), Expanded(child: values)]);
      }),
    );
  }
}

class _OverallBudgetTile extends StatelessWidget {
  const _OverallBudgetTile({required this.row});
  final BudgetRow row;

  @override
  Widget build(BuildContext context) {
    return AppCard(bordered: true, padding: const EdgeInsets.all(12),
      child: Row(key: Key('overallBudgetTile_${row.currencyCode}'), children: [
        AppIconTile(assetPath: 'assets/icons/budgets/budget_main.png',
          icon: Icons.savings_outlined, color: Theme.of(context).colorScheme.primary,
          size: AppIconTileSize.large),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.currencyCode, style: context.appTypography.caption),
          AppMoneyText(_formatter.format(Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode)),
            emphasis: AppMoneyEmphasis.secondary),
        ])),
      ]));
  }
}

class _CategoryBudgetTile extends ConsumerWidget {
  const _CategoryBudgetTile({required this.row, this.progress});
  final BudgetRow row;
  final CategoryBudgetProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final category = ref.watch(categoryByIdProvider(row.categoryId!));
    final colors = Theme.of(context).colorScheme;
    final tokens = context.appTokens;
    final p = progress;
    final over = p?.isOverBudget ?? false;
    final percent = p == null ? null : (p.usedRatio * 100).round();
    final amount = _formatter.format(Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode));
    final gradient = over ? tokens.colors.negativeGradient : tokens.colors.positiveGradient;
    final remaining = p == null ? null : (over
      ? l10n.overBudgetByAmountLabel(_formatter.format(p.calculation.remaining.abs()))
      : '${l10n.remainingLabel}: ${_formatter.format(p.calculation.remaining)}');
    return AppCard(bordered: true, padding: const EdgeInsets.all(12), child: Row(
      key: Key('categoryBudgetTile_${row.categoryId}_${row.currencyCode}'),
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        category.when(data: (c) => CategoryIdentityIcon(categoryId: c.id,
          iconKey: c.icon, colorKey: c.colorKey, size: AppIconTileSize.large),
          loading: () => const Icon(Icons.category_outlined),
          error: (e, st) => const Icon(Icons.category_outlined)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(category.when(data: (c) => c.name, loading: () => '…',
              error: (e, st) => row.categoryId!), style: context.appTypography.cardTitle)),
            if (percent != null) ...[
              const SizedBox(width: 8),
              Text('$percent%', key: Key('categoryProgressPercentUsed_${row.id}'),
                style: context.appTypography.caption?.copyWith(fontWeight: FontWeight.w600,
                  color: over ? colors.error : colors.onSurfaceVariant)),
            ],
          ]),
          const SizedBox(height: 3),
          Text(p == null ? '${row.currencyCode} · $amount'
            : '${_formatter.format(p.calculation.spent)} / $amount',
            key: Key('categoryProgressSpentOfBudget_${row.id}'),
            style: context.appTypography.secondaryBody),
          if (p != null) ...[
            const SizedBox(height: 8),
            Semantics(key: Key('categoryProgressRemaining_${row.id}'), label: remaining,
              child: AppProgressBar(value: p.usedRatio.clamp(0.0, 1.0), minHeight: 6,
                color: over ? colors.error : colors.primary,
                gradient: LinearGradient(colors: gradient ?? [over ? colors.error : colors.primary,
                  over ? colors.error : colors.primary]),
                semanticLabel: l10n.percentUsedLabel('$percent'))),
          ],
        ])),
      ],
    ));
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
                  DropdownMenuItem<String>(
                    value: currency.code,
                    // Checkpoint U2 (CurrencyBadge audit): the same
                    // small currency-code badge every other bare
                    // currency-code dropdown item already renders
                    // through (`add_account_form_screen.dart`) --
                    // currency remains the authoritative identifier,
                    // the region monogram is purely secondary
                    // decoration (see `CurrencyBadge`'s own doc
                    // comment on why EUR/shared currencies never
                    // imply a single country).
                    child: CurrencyBadge(currencyCode: currency.code, showRegionIndicator: true),
                  ),
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
                  DropdownMenuItem<String>(
                    value: currency.code,
                    // Checkpoint U2 (CurrencyBadge audit): the same
                    // small currency-code badge every other bare
                    // currency-code dropdown item already renders
                    // through (`add_account_form_screen.dart`) --
                    // currency remains the authoritative identifier,
                    // the region monogram is purely secondary
                    // decoration (see `CurrencyBadge`'s own doc
                    // comment on why EUR/shared currencies never
                    // imply a single country).
                    child: CurrencyBadge(currencyCode: currency.code, showRegionIndicator: true),
                  ),
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
