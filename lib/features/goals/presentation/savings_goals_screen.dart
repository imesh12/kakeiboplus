import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../domain/savings_goal_status.dart';
import 'savings_goal_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// The Beta 1 Task 3 savings goals list screen: every active goal for the
/// profile, each with its live progress, plus a way to create a new one.
/// Reached from the Profile screen's "Savings Goals" entry -- see
/// `lib/core/routing/app_router.dart` and `docs/14_DECISION_LOG.md`
/// ADR-022.
class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavingsGoalSummary>> summariesAsync = ref.watch(goalSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      body: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load goals: $e')),
        data: (List<SavingsGoalSummary> summaries) {
          if (summaries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No savings goals yet. Tap + to set one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: <Widget>[
              for (final SavingsGoalSummary summary in summaries) _GoalListTile(summary: summary),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addGoalFab'),
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _CreateGoalDialog()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalListTile extends StatelessWidget {
  const _GoalListTile({required this.summary});
  final SavingsGoalSummary summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final SavingsGoalStatus status = summary.calculation.status;
    final (Color statusColor, String statusLabel) = switch (status) {
      SavingsGoalStatus.completed => (colors.primary, 'Completed'),
      SavingsGoalStatus.overdue => (colors.error, 'Overdue'),
      SavingsGoalStatus.inProgress => (colors.onSurfaceVariant, 'In progress'),
    };

    return ListTile(
      key: Key('goalTile_${summary.id}'),
      leading: CircleAvatar(
        backgroundColor: colors.surfaceContainerHighest,
        child: Icon(
          status == SavingsGoalStatus.completed ? Icons.check_circle_outline : Icons.flag_outlined,
          color: statusColor,
        ),
      ),
      title: Text(summary.name),
      subtitle: Text(
        '${_formatter.format(summary.calculation.saved)} of '
        '${_formatter.format(summary.calculation.target)} · '
        '${summary.calculation.wholePercentSaved}% · $statusLabel',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.goalDetail(summary.id)),
    );
  }
}

class _CreateGoalDialog extends ConsumerStatefulWidget {
  const _CreateGoalDialog();

  @override
  ConsumerState<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<_CreateGoalDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _currencyCode = CurrencyRegistry.seed.first.code;
  Money? _parsedAmount;
  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final Money? amount = _parsedAmount;
    if (amount == null) return;
    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      await ref.read(savingsGoalRepositoryProvider).createGoal(
            profileId: profile.id,
            name: _nameController.text,
            targetAmount: amount,
            targetDate: _targetDate,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New savings goal'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('goalNameField'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Goal name'),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name for this goal.' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: const InputDecoration(labelText: 'Currency'),
              onChanged: (String? v) => setState(() => _currencyCode = v ?? _currencyCode),
              items: <DropdownMenuItem<String>>[
                for (final currency in CurrencyRegistry.seed)
                  DropdownMenuItem<String>(value: currency.code, child: Text(currency.code)),
              ],
            ),
            MoneyTextField(
              key: const Key('goalTargetAmountField'),
              currencyCode: _currencyCode,
              label: 'Target amount',
              onParsed: (Money? m) => _parsedAmount = m,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _targetDate == null
                    ? 'No target date'
                    : 'Target date: ${DateFormat.yMMMd().format(_targetDate!)}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: <Widget>[
                  TextButton(
                    key: const Key('pickGoalTargetDate'),
                    onPressed: _pickTargetDate,
                    child: const Text('Choose'),
                  ),
                  if (_targetDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear target date',
                      onPressed: () => setState(() => _targetDate = null),
                    ),
                ],
              ),
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
          key: const Key('saveGoal'),
          onPressed: _isSaving ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
