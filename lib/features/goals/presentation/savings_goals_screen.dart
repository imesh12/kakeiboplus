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
import '../../../l10n/generated/app_localizations.dart';
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<SavingsGoalSummary>> summariesAsync = ref.watch(goalSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsGoalsTitle)),
      body: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text(l10n.couldNotLoadGoals(e.toString()))),
        data: (List<SavingsGoalSummary> summaries) {
          if (summaries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noSavingsGoalsYetTapMessage,
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final SavingsGoalStatus status = summary.calculation.status;
    // Reuses the exact same status-label keys the Home dashboard's
    // `_PriorityGoalSummary` already established in CP6.3 -- same
    // enum, same three closed values, same meaning.
    final (Color statusColor, String statusLabel) = switch (status) {
      SavingsGoalStatus.completed => (colors.primary, l10n.goalStatusCompleted),
      SavingsGoalStatus.overdue => (colors.error, l10n.overdueLabel),
      SavingsGoalStatus.inProgress => (colors.onSurfaceVariant, l10n.goalStatusInProgress),
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
      // `l10n.ofAmount` is the same "of {target}" phrase the Home
      // dashboard's priority-goal card already uses (CP6.3); the bare
      // percent figure is interpolated the same way that card does too
      // -- neither needs its own new ARB key.
      subtitle: Text(
        '${_formatter.format(summary.calculation.saved)} '
        '${l10n.ofAmount(_formatter.format(summary.calculation.target))} · '
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newSavingsGoalDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('goalNameField'),
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.goalNameLabel),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? l10n.enterGoalNameMessage : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: InputDecoration(labelText: l10n.currencySection),
              onChanged: (String? v) => setState(() => _currencyCode = v ?? _currencyCode),
              items: <DropdownMenuItem<String>>[
                for (final currency in CurrencyRegistry.seed)
                  DropdownMenuItem<String>(value: currency.code, child: Text(currency.code)),
              ],
            ),
            MoneyTextField(
              key: const Key('goalTargetAmountField'),
              currencyCode: _currencyCode,
              label: l10n.targetAmountLabel,
              onParsed: (Money? m) => _parsedAmount = m,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                // The "Label: value" join is a structurally-safe pattern
                // (not a translated sentence fragment) -- see
                // `goal_detail_screen.dart`'s identical use of
                // `targetDateLabel` for the same reasoning. The date
                // itself is left exactly as `DateFormat.yMMMd()` already
                // formats it -- no date-formatting rewrite here.
                _targetDate == null
                    ? l10n.noTargetDateMessage
                    : '${l10n.targetDateLabel}: ${DateFormat.yMMMd().format(_targetDate!)}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: <Widget>[
                  TextButton(
                    key: const Key('pickGoalTargetDate'),
                    onPressed: _pickTargetDate,
                    child: Text(l10n.chooseButton),
                  ),
                  if (_targetDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.clearTargetDateTooltip,
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
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('saveGoal'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
