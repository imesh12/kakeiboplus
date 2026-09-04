import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
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
    final AsyncValue<List<BudgetRow>> budgetsAsync = ref.watch(currentMonthBudgetsProvider);
    final BudgetMonth month = ref.watch(currentBudgetMonthProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Budgets · ${month.toKey()}')),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load budgets: $e')),
        data: (List<BudgetRow> budgets) {
          if (budgets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No budgets set for this month yet. Tap + to set an overall monthly budget "
                  'or a category budget.',
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
            children: <Widget>[
              if (overall.isNotEmpty) ...<Widget>[
                const _SectionHeader('Overall budgets'),
                for (final BudgetRow row in overall) _OverallBudgetTile(row: row),
              ],
              if (category.isNotEmpty) ...<Widget>[
                const _SectionHeader('Category budgets'),
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
                title: const Text('Overall monthly budget'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showDialog<void>(context: context, builder: (_) => const _OverallBudgetDialog());
                },
              ),
              ListTile(
                key: const Key('addCategoryBudgetOption'),
                leading: const Icon(Icons.category_outlined),
                title: const Text('Category budget'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _OverallBudgetTile extends ConsumerWidget {
  const _OverallBudgetTile({required this.row});
  final BudgetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Money amount = Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode);
    return ListTile(
      key: Key('overallBudgetTile_${row.currencyCode}'),
      leading: const Icon(Icons.savings_outlined),
      title: Text(row.currencyCode),
      subtitle: Text(_formatter.format(amount)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            key: Key('editOverallBudget_${row.currencyCode}'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _OverallBudgetDialog(existing: row),
            ),
          ),
          IconButton(
            key: Key('deleteOverallBudget_${row.currencyCode}'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: () => unawaited(ref.read(budgetRepositoryProvider).softDelete(row.id)),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetTile extends ConsumerWidget {
  const _CategoryBudgetTile({required this.row});
  final BudgetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Money amount = Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode);
    final AsyncValue<CategoryRow> categoryAsync = ref.watch(categoryByIdProvider(row.categoryId!));
    return ListTile(
      key: Key('categoryBudgetTile_${row.categoryId}_${row.currencyCode}'),
      leading: const Icon(Icons.category_outlined),
      title: Text(
        categoryAsync.when(
          data: (CategoryRow c) => c.name,
          loading: () => '…',
          error: (Object e, StackTrace st) => row.categoryId!,
        ),
      ),
      subtitle: Text('${row.currencyCode} · ${_formatter.format(amount)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            key: Key('editCategoryBudget_${row.id}'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _CategoryBudgetDialog(existing: row),
            ),
          ),
          IconButton(
            key: Key('deleteCategoryBudget_${row.id}'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: () => unawaited(ref.read(budgetRepositoryProvider).softDelete(row.id)),
          ),
        ],
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
    final bool editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit overall monthly budget' : 'Set overall monthly budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: const InputDecoration(labelText: 'Currency'),
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
              label: 'Monthly budget amount',
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveOverallBudget'),
          onPressed: _isSaving ? null : _submit,
          child: const Text('Save'),
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
    final bool editing = widget.existing != null;
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider('expense'));

    return AlertDialog(
      title: Text(editing ? 'Edit category budget' : 'Set category budget'),
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
              error: (Object e, StackTrace st) => Text('Could not load categories: $e'),
              data: (List<CategoryRow> categories) {
                return DropdownButtonFormField<String>(
                  key: const Key('categoryBudgetCategoryField'),
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  // Fixed while editing -- see the currency-field comment
                  // in _OverallBudgetDialogState for the same reasoning.
                  onChanged: editing ? null : (String? v) => setState(() => _categoryId = v),
                  items: <DropdownMenuItem<String>>[
                    for (final CategoryRow c in categories)
                      DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
                  ],
                  validator: (String? v) => v == null ? 'Choose a category.' : null,
                );
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: const InputDecoration(labelText: 'Currency'),
              onChanged: editing ? null : (String? v) => setState(() => _currencyCode = v ?? _currencyCode),
              items: <DropdownMenuItem<String>>[
                for (final currency in CurrencyRegistry.seed)
                  DropdownMenuItem<String>(value: currency.code, child: Text(currency.code)),
              ],
            ),
            MoneyTextField(
              key: const Key('categoryBudgetAmountField'),
              currencyCode: _currencyCode,
              label: 'Category budget amount',
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveCategoryBudget'),
          onPressed: _isSaving ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
