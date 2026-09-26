import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../domain/category_color.dart';
import 'category_icon_color_picker.dart';
import 'category_identity_icon.dart';
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
                  // Checkpoint U1: every category row now shows its own
                  // resolved icon+color, via the ONE shared
                  // `CategoryIdentityIcon` widget every other category
                  // surface (Transactions/Budgets/Recurring pickers) also
                  // renders through -- see that widget's own doc comment
                  // for why this guarantees identical rendering, not just
                  // visual similarity, across screens.
                  leading: CategoryIdentityIcon(
                    categoryId: category.id,
                    iconKey: category.icon,
                    colorKey: category.colorKey,
                    size: AppIconTileSize.small,
                  ),
                  title: Text(category.name, style: context.appTypography.cardTitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (category.isSystem)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: AppStatusChip(
                            label: l10n.systemCategoryIndicatorLabel,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      IconButton(
                        key: Key('editCategory_${category.id}'),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.editCategoryTooltip,
                        onPressed: () => _showEditCategoryDialog(context, category),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showEditCategoryDialog(BuildContext context, CategoryRow category) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => _EditCategoryDialog(category: category),
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
  // Checkpoint U1: both start unset -- a category created without ever
  // touching either picker still gets a real, deterministic icon/color
  // at render time via `categoryIconFor`/`categoryColorFor`'s own
  // null-safe fallbacks (see those functions' doc comments), exactly
  // like every category created before this checkpoint already does.
  String? _iconKey;
  CategoryColorKey? _colorKey;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Re-entrancy guard against a double-tap/rapid-repeat Add -- see
    // `docs/14_DECISION_LOG.md` ADR-042/ADR-043's established pattern
    // (first line of the async handler, before any `setState`, since
    // `setState` only takes effect on the next rendered frame).
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      await ref.read(categoryRepositoryProvider).createCategory(
            profileId: profile.id,
            name: _nameController.text.trim(),
            type: widget.type,
            icon: _iconKey,
            colorKey: _colorKey?.storageValue,
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
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.categoryNameLabel),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.enterAccountNameMessage : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text(l10n.categoryIconFieldLabel, style: context.appTypography.caption),
              const SizedBox(height: 8),
              CategoryIconPicker(
                selectedIconKey: _iconKey,
                onChanged: (String key) => setState(() => _iconKey = key),
              ),
              const SizedBox(height: 16),
              Text(l10n.categoryColorFieldLabel, style: context.appTypography.caption),
              const SizedBox(height: 8),
              CategoryColorPicker(
                selectedColorKey: _colorKey,
                onChanged: (CategoryColorKey key) => setState(() => _colorKey = key),
              ),
            ],
          ),
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

/// Checkpoint U1: lets the user change a category's icon/color (and, for
/// a non-system category, its name). See
/// `CategoryRepository.updateCategory`'s own doc comment for why a
/// system category's name stays fixed while its icon/color remain
/// editable -- both are presentation metadata only.
class _EditCategoryDialog extends ConsumerStatefulWidget {
  const _EditCategoryDialog({required this.category});

  final CategoryRow category;

  @override
  ConsumerState<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends ConsumerState<_EditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.category.name);
  bool _isSaving = false;
  late String? _iconKey = widget.category.icon;
  // Pre-selects the same swatch `CategoryIdentityIcon` would already be
  // rendering for this category (its stored key, or the deterministic
  // per-id fallback if it has none yet) -- so the picker's "current
  // selection" always matches what the user sees elsewhere for this
  // category, never a blank/unselected picker for a category that
  // visually already has a color.
  late CategoryColorKey _colorKey = resolveCategoryColorKey(
    categoryId: widget.category.id,
    storedColorKey: widget.category.colorKey,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(categoryRepositoryProvider).updateCategory(
            id: widget.category.id,
            name: widget.category.isSystem ? null : _nameController.text.trim(),
            icon: _iconKey,
            colorKey: _colorKey.storageValue,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editCategoryDialogTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!widget.category.isSystem)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: l10n.categoryNameLabel),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.enterAccountNameMessage : null,
                    autofocus: true,
                  ),
                ),
              Text(l10n.categoryIconFieldLabel, style: context.appTypography.caption),
              const SizedBox(height: 8),
              CategoryIconPicker(
                selectedIconKey: _iconKey,
                onChanged: (String key) => setState(() => _iconKey = key),
              ),
              const SizedBox(height: 16),
              Text(l10n.categoryColorFieldLabel, style: context.appTypography.caption),
              const SizedBox(height: 8),
              CategoryColorPicker(
                selectedColorKey: _colorKey,
                onChanged: (CategoryColorKey key) => setState(() => _colorKey = key),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.editCategoryButton),
        ),
      ],
    );
  }
}
