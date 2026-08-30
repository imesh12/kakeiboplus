import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import 'category_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(tabs: <Widget>[Tab(text: 'Expense'), Tab(text: 'Income')]),
        ),
        body: const TabBarView(
          children: <Widget>[
            _CategoryList(type: 'expense'),
            _CategoryList(type: 'income'),
          ],
        ),
        floatingActionButton: Builder(
          builder: (BuildContext context) {
            final int tabIndex = DefaultTabController.of(context).index;
            return FloatingActionButton(
              onPressed: () => _showAddCategoryDialog(context, tabIndex == 0 ? 'expense' : 'income'),
              child: const Icon(Icons.add),
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
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace st) => Center(child: Text('Could not load categories: $e')),
      data: (List<CategoryRow> categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('No categories yet.'));
        }
        return ListView(
          children: <Widget>[
            for (final CategoryRow category in categories)
              ListTile(
                title: Text(category.name),
                trailing: category.isSystem ? const Text('System') : null,
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
    return AlertDialog(
      title: Text('Add ${widget.type} category'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
          autofocus: true,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
