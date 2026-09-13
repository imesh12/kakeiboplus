import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_chip.dart';
import 'category_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.categoriesScreenTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.transactionTypeExpense),
              Tab(text: l10n.transactionTypeIncome),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _CategoryList(type: 'expense'),
            _CategoryList(type: 'income'),
          ],
        ),
        floatingActionButton: Builder(
          builder: (BuildContext context) {
            final TabController tabController = DefaultTabController.of(context);
            // The Builder above only depends on the TabController's IDENTITY
            // (see `_TabControllerScope.updateShouldNotify`, which compares
            // controller instances, not `.index`) -- switching tabs never
            // changes which controller instance is in scope, so without this
            // AnimatedBuilder the FAB's captured `tabIndex` stayed frozen at
            // whatever it was on first build (0 / Expense) even after the
            // user switched to the Income tab. Listening to the controller
            // directly (it's a ChangeNotifier) fixes that.
            return AnimatedBuilder(
              animation: tabController,
              builder: (BuildContext context, Widget? _) {
                final int tabIndex = tabController.index;
                return FloatingActionButton(
                  onPressed: () =>
                      _showAddCategoryDialog(context, tabIndex == 0 ? 'expense' : 'income'),
                  child: const Icon(Icons.add),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context, String type) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => _AddCategoryDialog(type: type),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider(type));
    final AppLocalizations l10n = AppLocalizations.of(context);
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace st) =>
          Center(child: Text(l10n.couldNotLoadCategories(e.toString()))),
      data: (List<CategoryRow> categories) {
        if (categories.isEmpty) {
          return Center(
            child: Text(
              l10n.noCategoriesYetMessage,
              style: context.appTypography.secondaryBody,
            ),
          );
        }
        final ColorScheme colors = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            for (final CategoryRow category in categories)
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(category.name, style: context.appTypography.cardTitle),
                  trailing: category.isSystem
                      ? AppStatusChip(
                          label: l10n.systemCategoryIndicatorLabel,
                          color: colors.onSurfaceVariant,
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog({required this.type});

  final String type;

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      await ref.read(categoryRepositoryProvider).createCategory(
            profileId: profile.id,
            name: _nameController.text.trim(),
            type: widget.type,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String dialogTitle =
        widget.type == 'income' ? l10n.addIncomeCategoryDialogTitle : l10n.addExpenseCategoryDialogTitle;
    return AlertDialog(
      title: Text(dialogTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(labelText: l10n.categoryNameLabel),
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.enterAccountNameMessage : null,
          autofocus: true,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.addCategoryButton),
        ),
      ],
    );
  }
}
