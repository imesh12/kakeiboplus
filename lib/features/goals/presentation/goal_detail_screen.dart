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
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_section_header.dart';
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<SavingsGoalSummary?> summaryAsync = ref.watch(goalSummaryProvider(goalId));

    return Scaffold(
      appBar: AppBar(
        // `summary.name` is user-entered content and is never
        // translated; the fallback word shown only while loading (or if
        // the goal can't be found yet) is the only localizable piece
        // here.
        title: Text(summaryAsync.valueOrNull?.name ?? l10n.goalFallbackTitle),
        actions: <Widget>[
          if (summaryAsync.valueOrNull != null) ...<Widget>[
            IconButton(
              key: const Key('editGoal'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editGoalAction,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _EditGoalDialog(goal: summaryAsync.requireValue!.goal),
              ),
            ),
            IconButton(
              key: const Key('deleteGoal'),
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteGoalTooltip,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text(l10n.couldNotLoadGoalDetail(e.toString()))),
        data: (SavingsGoalSummary? summary) {
          if (summary == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.goalNoLongerAvailableMessage,
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.deleteGoalConfirmTitle),
        content: Text(l10n.deleteGoalConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmDeleteGoal'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteButton),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final SavingsGoalCalculation calc = summary.calculation;

    // Same shared status-label keys as the goals list (`_GoalListTile`)
    // and the Home dashboard's priority-goal card (CP6.3) -- one closed
    // enum, one set of translations, reused everywhere it's shown.
    final (Color statusColor, String statusLabel) = switch (calc.status) {
      SavingsGoalStatus.completed => (colors.primary, l10n.goalStatusCompleted),
      SavingsGoalStatus.overdue => (colors.error, l10n.overdueLabel),
      SavingsGoalStatus.inProgress => (colors.onSurfaceVariant, l10n.goalStatusInProgress),
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
        AppCard(
          bordered: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _GoalHeroAmountRow(
                savedText: _formatter.format(calc.saved),
                savedStyle: context.appTypography.largeMoney,
                statusLabel: statusLabel,
                statusStyle: text.labelMedium?.copyWith(color: statusColor),
                statusColor: statusColor,
              ),
              Text(
                // Same `ofAmount` reuse as the goals list -- see that file's
                // comment.
                '${l10n.ofAmount(_formatter.format(calc.target))} · ${calc.wholePercentSaved}%',
                style: context.appTypography.secondaryBody,
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
                label: l10n.remainingLabel,
                value: _formatter.format(calc.remaining),
              ),
              if (summary.goal.targetDate != null)
                _DetailRow(
                  label: l10n.targetDateLabel,
                  // `targetDate` is a calendar-only UTC-midnight value -- see
                  // `goal_target_date.dart`. Formatting it directly (never
                  // `.toLocal()`) is deliberate: converting it to local time
                  // could shift which calendar day it displays as, exactly the
                  // bug `normalizeCalendarDateToUtc` exists to prevent at
                  // write time. Contrast `_ContributionTile` below, where
                  // `contributedAt` IS a genuine instant and `.toLocal()` is
                  // correct there. Only the row's label is localized; the
                  // date-format policy itself is untouched by CP6.6.
                  value: DateFormat.yMMMd().format(summary.goal.targetDate!),
                ),
              if (calc.recommendedDailyContribution != null)
                _DetailRow(
                  label: l10n.recommendedDailyContributionLabel,
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
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppSectionHeader(title: l10n.contributionHistoryTitle, eyebrow: true),
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
            child: Text(label, style: context.appTypography.secondaryBody),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.appTypography.body?.copyWith(fontWeight: FontWeight.w600),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<SavingsGoalContributionRow>> contributionsAsync =
        ref.watch(goalContributionsProvider(goalId));

    return contributionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace st) =>
          Text(l10n.couldNotLoadContributionHistory(e.toString())),
      data: (List<SavingsGoalContributionRow> contributions) {
        if (contributions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.noContributionsYetMessage),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Money amount =
        Money.fromMinorUnits(contribution.amountMinorUnits, contribution.currencyCode);
    return AppCard(
      bordered: true,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        key: Key('contributionTile_${contribution.id}'),
        leading: const Icon(Icons.arrow_upward_rounded),
        title: AppMoneyText(_formatter.format(amount), emphasis: AppMoneyEmphasis.secondary),
        // `contributedAt` IS a genuine instant -- `.toLocal()` here is
        // correct, unlike `targetDate` above. See that comment for why
        // these two use different rules. Only this row's tooltip is
        // localized; the date/time formatting itself is untouched.
        subtitle: Text(
          DateFormat.yMMMd().add_jm().format(contribution.contributedAt.toLocal()),
          style: context.appTypography.caption,
        ),
        trailing: IconButton(
          key: Key('deleteContribution_${contribution.id}'),
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.removeTooltip,
          onPressed: () => unawaited(
            ref.read(savingsGoalContributionRepositoryProvider).softDeleteContribution(contribution.id),
          ),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addContributionDialogTitle),
      content: Form(
        key: _formKey,
        child: MoneyTextField(
          key: const Key('contributionAmountField'),
          currencyCode: widget.currencyCode,
          label: l10n.amountLabel,
          onParsed: (Money? m) => _parsedAmount = m,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('saveContribution'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.addContributionButton),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editGoalAction),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('editGoalNameField'),
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.goalNameLabel),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? l10n.enterGoalNameMessage : null,
            ),
            MoneyTextField(
              key: const Key('editGoalTargetAmountField'),
              currencyCode: widget.goal.currencyCode,
              label: l10n.targetAmountLabel,
              initialValue: Money.fromMinorUnits(widget.goal.targetAmountMinorUnits, widget.goal.currencyCode)
                  .toMajorUnitsString(),
              onParsed: (Money? m) => _parsedAmount = m,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _targetDate == null
                    ? l10n.noTargetDateMessage
                    : '${l10n.targetDateLabel}: ${DateFormat.yMMMd().format(_targetDate!)}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: <Widget>[
                  TextButton(
                    key: const Key('editPickGoalTargetDate'),
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
          key: const Key('saveEditGoal'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
