import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../../categories/presentation/category_providers.dart';
import '../domain/budget_month.dart';
import 'budget_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// The Beta 1 budget management screen: create/update/remove the
/// profile's overall monthly budget (per currency) and its category
/// budgets, for the current calendar month. Reached from the Profile
/// screen's "Budgets" entry and from the Home dashboard's budget card
/// call-to-action -- see `lib/core/routing/app_router.dart`.
///
/// Beta 1 scope: this screen only manages the *current* calendar month
/// (see `currentBudgetMonthProvider`) -- there is no month picker here.
/// Historical/future month budgeting is not part of this task.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<BudgetRow>> budgetsAsync = ref.watch(currentMonthBudgetsProvider);
    final BudgetMonth month = ref.watch(currentBudgetMonthProvider);

    return Scaffold(
      // The "YYYY-MM" month key itself is left exactly as
      // `BudgetMonth.toKey()` already produces it -- see that method's
      // doc comment; only the surrounding "Budgets ·" word is
      // localized text.
      appBar: AppBar(title: Text(l10n.budgetsScreenTitle(month.toKey()))),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text(l10n.couldNotLoadBudgets(e.toString()))),
        data: (List<BudgetRow> budgets) {
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

          final List<BudgetRow> overall =
              budgets.where((BudgetRow b) => b.categoryId == null).toList();
          final List<BudgetRow> category =
              budgets.where((BudgetRow b) => b.categoryId != null).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
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
                for (final BudgetRow row in category) _CategoryBudgetTile(row: row),
              ],
            ],
          );
        },
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
  const _CategoryBudgetTile({required this.row});
  final BudgetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Money amount = Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode);
    final AsyncValue<CategoryRow> categoryAsync = ref.watch(categoryByIdProvider(row.categoryId!));
    return AppCard(
      bordered: true,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        key: Key('categoryBudgetTile_${row.categoryId}_${row.currencyCode}'),
        leading: const Icon(Icons.category_outlined),
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
      final BudgetMonth month = ref.read(currentBudgetMonthProvider);
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
      final BudgetMonth month = ref.read(currentBudgetMonthProvider);
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
