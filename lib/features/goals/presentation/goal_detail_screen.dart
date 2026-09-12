import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../domain/savings_goal_calculation.dart';
import '../domain/savings_goal_milestones.dart';
import '../domain/savings_goal_status.dart';
import 'savings_goal_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// The Beta 1 Task 3 goal detail screen: full progress for one savings
/// goal, its contribution history, adding a new contribution, editing
/// the goal, and deleting it. See `docs/14_DECISION_LOG.md` ADR-022.
///
/// If [goalId] no longer names an active goal -- soft-deleted, or never
/// existed -- this resolves to an explicit "no longer available" state
/// rather than silently showing stale data (ADR-022's requirement that a
/// deleted goal is unavailable below the UI layer, not merely by UI
/// convention -- `goalSummaryProvider` already guarantees this at the
/// provider layer; this screen just renders what it's given).
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({required this.goalId, super.key});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SavingsGoalSummary?> summaryAsync = ref.watch(goalSummaryProvider(goalId));

    return Scaffold(
      appBar: AppBar(
        title: Text(summaryAsync.valueOrNull?.name ?? 'Goal'),
        actions: <Widget>[
          if (summaryAsync.valueOrNull != null) ...<Widget>[
            IconButton(
              key: const Key('editGoal'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit goal',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _EditGoalDialog(goal: summaryAsync.requireValue!.goal),
              ),
            ),
            IconButton(
              key: const Key('deleteGoal'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete goal',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load this goal: $e')),
        data: (SavingsGoalSummary? summary) {
          if (summary == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This goal is no longer available.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _GoalDetailBody(summary: summary);
        },
      ),
      floatingActionButton: summaryAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              key: const Key('addContributionFab'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _AddContributionDialog(
                  goalId: goalId,
                  currencyCode: summaryAsync.requireValue!.goal.currencyCode,
                ),
              ),
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: const Text(
          'Its contribution history is kept, but the goal itself will no longer be active.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmDeleteGoal'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(savingsGoalRepositoryProvider).softDeleteGoal(goalId);
      if (context.mounted) context.pop();
    }
  }
}

class _GoalDetailBody extends ConsumerWidget {
  const _GoalDetailBody({required this.summary});
  final SavingsGoalSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final SavingsGoalCalculation calc = summary.calculation;

    final (Color statusColor, String statusLabel) = switch (calc.status) {
      SavingsGoalStatus.completed => (colors.primary, 'Completed'),
      SavingsGoalStatus.overdue => (colors.error, 'Overdue'),
      SavingsGoalStatus.inProgress => (colors.onSurfaceVariant, 'In progress'),
    };

    // `ratio` here is presentation-only -- never fed back into any
    // calculation -- and only the progress bar's fill fraction clamps to
    // 1.0. `calc.wholePercentSaved` (the TEXT below) is deliberately a
    // separate, floor-rounded, uncapped-above-100 value -- see
    // `SavingsGoalCalculation.wholePercentSaved`'s doc comment for why it
    // must never read "100%" before `calc.status` is actually completed.
    final double ratio = calc.target.minorUnits == 0
        ? 0
        : calc.saved.minorUnits / calc.target.minorUnits;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _GoalHeroAmountRow(
          savedText: _formatter.format(calc.saved),
          savedStyle: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          statusLabel: statusLabel,
          statusStyle: text.labelMedium?.copyWith(color: statusColor),
          statusColor: statusColor,
        ),
        Text(
          'of ${_formatter.format(calc.target)} · ${calc.wholePercentSaved}%',
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHighest,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 16),
        _DetailRow(
          label: 'Remaining',
          value: _formatter.format(calc.remaining),
        ),
        if (summary.goal.targetDate != null)
          _DetailRow(
            label: 'Target date',
            // `targetDate` is a calendar-only UTC-midnight value -- see
            // `goal_target_date.dart`. Formatting it directly (never
            // `.toLocal()`) is deliberate: converting it to local time
            // could shift which calendar day it displays as, exactly the
            // bug `normalizeCalendarDateToUtc` exists to prevent at
            // write time. Contrast `_ContributionTile` below, where
            // `contributedAt` IS a genuine instant and `.toLocal()` is
            // correct there.
            value: DateFormat.yMMMd().format(summary.goal.targetDate!),
          ),
        if (calc.recommendedDailyContribution != null)
          _DetailRow(
            label: 'Recommended daily contribution',
            value: _formatter.format(calc.recommendedDailyContribution!),
          ),
        if (calc.reachedMilestones.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final int milestone in savingsGoalMilestoneThresholds)
                Chip(
                  label: Text('$milestone%'),
                  avatar: calc.reachedMilestones.contains(milestone)
                      ? const Icon(Icons.check, size: 16)
                      : null,
                  backgroundColor: calc.reachedMilestones.contains(milestone)
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Contribution history', style: text.titleMedium),
        const SizedBox(height: 4),
        _ContributionHistory(goalId: summary.id),
      ],
    );
  }
}

/// CP5.4a: the goal detail hero row -- the authoritative saved amount
/// (`MoneyFormatter`'s exact output, [savedText]) next to the status
/// chip (Completed/Overdue/In progress, [statusLabel]/[statusColor]).
///
/// The saved amount must always render in full -- never ellipsized,
/// clipped, or shrunk in a `FittedBox` -- while the status chip is
/// short, fixed-content, and free to move below the amount when there
/// isn't room for both on one line. Measures both pieces' actual
/// rendered widths ([TextPainter], respecting
/// [MediaQuery.textScalerOf] and [Directionality.of]) against the row's
/// real available width ([LayoutBuilder]) rather than guessing from
/// string length or branching on currency -- the same technique
/// `_AdaptiveAmountLine` already uses on the Home dashboard (CP5.1).
///
/// Side by side (`Key('goalHeroHorizontal')`): amount on the left in an
/// `Expanded` (the measurement already proved the full string fits, so
/// this never forces a mid-number wrap), chip on the right -- visually
/// the same arrangement this row always had, now reached only when it
/// actually fits.
///
/// Stacked (`Key('goalHeroStacked')`): amount first at full width, chip
/// below it -- both keep their existing styling and colors; only the
/// arrangement changes. Status semantics/logic are computed by the
/// caller and passed straight through -- this widget never alters them.
class _GoalHeroAmountRow extends StatelessWidget {
  const _GoalHeroAmountRow({
    required this.savedText,
    required this.savedStyle,
    required this.statusLabel,
    required this.statusStyle,
    required this.statusColor,
  });

  final String savedText;
  final TextStyle? savedStyle;
  final String statusLabel;
  final TextStyle? statusStyle;
  final Color statusColor;

  /// Deliberate minimum breathing room between the amount and the chip
  /// in the side-by-side arrangement -- the previous unconditional `Row`
  /// had no explicit gap here (whatever space was left over after the
  /// `Expanded` text simply wasn't occupied), so this is a small,
  /// intentional addition rather than a behavior change worth flagging
  /// as a regression.
  static const double _gap = 12;
  static const EdgeInsets _chipPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 4);

  @override
  Widget build(BuildContext context) {
    final Widget money = Text(
      savedText,
      key: const Key('goalSavedAmount'),
      style: savedStyle,
    );
    final Widget chip = Container(
      padding: _chipPadding,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(statusLabel, style: statusStyle),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextScaler scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final double moneyWidth = (TextPainter(
          text: TextSpan(text: savedText, style: savedStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout())
            .width;
        final double chipTextWidth = (TextPainter(
          text: TextSpan(text: statusLabel, style: statusStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout())
            .width;
        final double chipWidth = chipTextWidth + _chipPadding.horizontal;

        final bool fitsHorizontal = moneyWidth + _gap + chipWidth <= constraints.maxWidth;

        if (fitsHorizontal) {
          return Row(
            key: const Key('goalHeroHorizontal'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: money),
              const SizedBox(width: _gap),
              chip,
            ],
          );
        }

        return Column(
          key: const Key('goalHeroStacked'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            money,
            const SizedBox(height: 8),
            chip,
          ],
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    // `label`/`value` each get a flexible share of the row's width
    // (rather than sizing to their own intrinsic width) so a long
    // label (e.g. "Recommended daily contribution") or a long
    // formatted value can wrap onto multiple lines instead of
    // overflowing a narrow screen -- neither is ever clipped or
    // truncated, and no width here is hard-coded.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionHistory extends ConsumerWidget {
  const _ContributionHistory({required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavingsGoalContributionRow>> contributionsAsync =
        ref.watch(goalContributionsProvider(goalId));

    return contributionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace st) => Text('Could not load contribution history: $e'),
      data: (List<SavingsGoalContributionRow> contributions) {
        if (contributions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No contributions yet.'),
          );
        }
        return Column(
          children: <Widget>[
            for (final SavingsGoalContributionRow contribution in contributions)
              _ContributionTile(contribution: contribution),
          ],
        );
      },
    );
  }
}

class _ContributionTile extends ConsumerWidget {
  const _ContributionTile({required this.contribution});
  final SavingsGoalContributionRow contribution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Money amount =
        Money.fromMinorUnits(contribution.amountMinorUnits, contribution.currencyCode);
    return ListTile(
      key: Key('contributionTile_${contribution.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.arrow_upward_rounded),
      title: Text(_formatter.format(amount)),
      // `contributedAt` IS a genuine instant -- `.toLocal()` here is
      // correct, unlike `targetDate` above. See that comment for why
      // these two use different rules.
      subtitle: Text(DateFormat.yMMMd().add_jm().format(contribution.contributedAt.toLocal())),
      trailing: IconButton(
        key: Key('deleteContribution_${contribution.id}'),
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove',
        onPressed: () => unawaited(
          ref.read(savingsGoalContributionRepositoryProvider).softDeleteContribution(contribution.id),
        ),
      ),
    );
  }
}

class _AddContributionDialog extends ConsumerStatefulWidget {
  const _AddContributionDialog({required this.goalId, required this.currencyCode});
  final String goalId;
  final String currencyCode;

  @override
  ConsumerState<_AddContributionDialog> createState() => _AddContributionDialogState();
}

class _AddContributionDialogState extends ConsumerState<_AddContributionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Money? _parsedAmount;
  bool _isSaving = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final Money? amount = _parsedAmount;
    if (amount == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(savingsGoalContributionRepositoryProvider).addContribution(
            goalId: widget.goalId,
            amount: amount,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a contribution'),
      content: Form(
        key: _formKey,
        child: MoneyTextField(
          key: const Key('contributionAmountField'),
          currencyCode: widget.currencyCode,
          label: 'Amount',
          onParsed: (Money? m) => _parsedAmount = m,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveContribution'),
          onPressed: _isSaving ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EditGoalDialog extends ConsumerStatefulWidget {
  const _EditGoalDialog({required this.goal});
  final SavingsGoalRow goal;

  @override
  ConsumerState<_EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends ConsumerState<_EditGoalDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  Money? _parsedAmount;
  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _parsedAmount = Money.fromMinorUnits(widget.goal.targetAmountMinorUnits, widget.goal.currencyCode);
    _targetDate = widget.goal.targetDate;
  }

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
      // The target-date `Value` sentinel always carries an explicit
      // replace-or-clear here (never `Value.absent()`) -- this dialog
      // always shows the FULL current state and submits the full edited
      // state, so "leave unchanged" isn't a distinct case a save from
      // this form ever needs; `Value.absent()` exists for a caller that
      // only wants to touch one field, which this dialog isn't.
      await ref.read(savingsGoalRepositoryProvider).updateGoal(
            id: widget.goal.id,
            name: _nameController.text,
            targetAmount: amount,
            targetDate: Value<DateTime?>(_targetDate),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit goal'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('editGoalNameField'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Goal name'),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name for this goal.' : null,
            ),
            MoneyTextField(
              key: const Key('editGoalTargetAmountField'),
              currencyCode: widget.goal.currencyCode,
              label: 'Target amount',
              initialValue: Money.fromMinorUnits(widget.goal.targetAmountMinorUnits, widget.goal.currencyCode)
                  .toMajorUnitsString(),
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
                    key: const Key('editPickGoalTargetDate'),
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
          key: const Key('saveEditGoal'),
          onPressed: _isSaving ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
