import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/recurring_rule_repository.dart'
    show
        InvalidRecurringRuleAmountException,
        InvalidRecurringRuleNameException,
        RecurringRuleNotFoundException;
import '../../../core/money/currency_mismatch_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_scheduler.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import '../domain/recurrence_frequency.dart';
import '../domain/recurring_rule_kind.dart';
import 'recurring_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// [kind]'s translated label -- reuses the same transaction-type words
/// established for Add/Edit Transaction (`transactionTypeExpense/Income/
/// Transfer`), since a recurring rule's `kind` is the same closed
/// concept (see `RecurringRuleKind`'s own doc comment).
String _kindLabel(AppLocalizations l10n, RecurringRuleKind kind) => switch (kind) {
      RecurringRuleKind.expense => l10n.transactionTypeExpense,
      RecurringRuleKind.income => l10n.transactionTypeIncome,
      RecurringRuleKind.transfer => l10n.transactionTypeTransfer,
    };

/// [frequency]'s translated label. Purely a display concern -- the
/// persisted value (`RecurringRuleRow.frequency`, written via
/// `RecurrenceFrequency.name`) is never touched.
String _frequencyLabel(AppLocalizations l10n, RecurrenceFrequency frequency) => switch (frequency) {
      RecurrenceFrequency.daily => l10n.recurrenceFrequencyDaily,
      RecurrenceFrequency.weekly => l10n.recurrenceFrequencyWeekly,
      RecurrenceFrequency.monthly => l10n.recurrenceFrequencyMonthly,
      RecurrenceFrequency.yearly => l10n.recurrenceFrequencyYearly,
    };

/// The Beta 1 Task 4A recurring screen: every pending item (overdue, due
/// today, or upcoming) derived from the profile's active
/// [RecurringRuleRow]s, plus creating, editing, and deleting rules. See
/// `docs/14_DECISION_LOG.md` ADR-023. Reached from the Profile screen's
/// "Recurring" entry and the Home dashboard's recurring summary card --
/// no new bottom-nav item, same precedent Budgets/Savings Goals set.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<RecurringPendingItem>> itemsAsync =
        ref.watch(recurringPendingItemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurringTitle)),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text(l10n.couldNotLoadRecurringRules(e.toString()))),
        data: (List<RecurringPendingItem> items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noRecurringRulesYetTapMessage,
                  textAlign: TextAlign.center,
                  style: context.appTypography.secondaryBody,
                ),
              ),
            );
          }
          final List<RecurringPendingItem> overdue =
              items.where((i) => i.urgency == RecurringItemUrgency.overdue).toList();
          final List<RecurringPendingItem> dueToday =
              items.where((i) => i.urgency == RecurringItemUrgency.dueToday).toList();
          final List<RecurringPendingItem> upcoming =
              items.where((i) => i.urgency == RecurringItemUrgency.upcoming).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              if (overdue.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: AppSectionHeader(
                    key: const Key('sectionOverdue'),
                    title: l10n.overdueLabel,
                    eyebrow: true,
                  ),
                ),
                for (final RecurringPendingItem item in overdue) _PendingItemTile(item: item),
              ],
              if (dueToday.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: AppSectionHeader(
                    key: const Key('sectionDueToday'),
                    title: l10n.recurringStatusDueToday,
                    eyebrow: true,
                  ),
                ),
                for (final RecurringPendingItem item in dueToday) _PendingItemTile(item: item),
              ],
              if (upcoming.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: AppSectionHeader(
                    key: const Key('sectionUpcoming'),
                    title: l10n.recurringStatusUpcoming,
                    eyebrow: true,
                  ),
                ),
                for (final RecurringPendingItem item in upcoming) _PendingItemTile(item: item),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addRecurringRuleFab'),
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _RuleDialog()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// One pending item: the underlying rule's summary plus urgency-specific
/// styling, edit/delete for the rule, and post/skip for this specific
/// scheduled date.
class _PendingItemTile extends ConsumerStatefulWidget {
  const _PendingItemTile({required this.item});
  final RecurringPendingItem item;

  @override
  ConsumerState<_PendingItemTile> createState() => _PendingItemTileState();
}

class _PendingItemTileState extends ConsumerState<_PendingItemTile> {
  bool _isBusy = false;

  String get _dateKey => widget.item.scheduledDateUtc.toIso8601String();

  Future<void> _handle(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations dialogL10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(dialogL10n.deleteRecurringRuleConfirmTitle),
          content: Text(dialogL10n.deleteRecurringRuleConfirmMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogL10n.deleteButton),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _handle(() => ref.read(recurringRuleRepositoryProvider).softDelete(widget.item.rule.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RecurringRuleRow rule = widget.item.rule;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Money amount = Money.fromMinorUnits(rule.amountMinorUnits, rule.currencyCode);

    final (Color urgencyColor, String urgencyLabel) = switch (widget.item.urgency) {
      RecurringItemUrgency.overdue => (colors.error, l10n.overdueLabel),
      RecurringItemUrgency.dueToday => (colors.primary, l10n.recurringStatusDueToday),
      RecurringItemUrgency.upcoming => (colors.onSurfaceVariant, l10n.recurringStatusUpcoming),
    };
    final IconData kindIcon = switch (RecurringRuleKind.values.byName(rule.kind)) {
      RecurringRuleKind.expense => Icons.trending_down_rounded,
      RecurringRuleKind.income => Icons.trending_up_rounded,
      RecurringRuleKind.transfer => Icons.swap_horiz_rounded,
    };

    return AppCard(
      key: Key('pendingItem_${rule.id}_$_dateKey'),
      bordered: true,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(kindIcon, color: colors.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.name,
                  style: context.appTypography.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppStatusChip(label: urgencyLabel, color: urgencyColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatter.format(amount)} · ${DateFormat.yMMMd().format(widget.item.scheduledDateUtc)}',
            style: context.appTypography.secondaryBody,
          ),
          const SizedBox(height: 8),
          Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                IconButton(
                  key: Key('editRule_${rule.id}'),
                  tooltip: l10n.editTooltip,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _isBusy
                      ? null
                      : () => showDialog<void>(
                            context: context,
                            builder: (_) => _RuleDialog(existingRule: rule),
                          ),
                ),
                IconButton(
                  key: Key('deleteRule_${rule.id}'),
                  tooltip: l10n.deleteRuleTooltip,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _isBusy ? null : _confirmDelete,
                ),
                OutlinedButton(
                  key: Key('skipOccurrence_${rule.id}_$_dateKey'),
                  onPressed: _isBusy
                      ? null
                      : () => _handle(
                            () => ref.read(recurringOccurrenceRepositoryProvider).skipOccurrence(
                                  ruleId: rule.id,
                                  scheduledDateUtc: widget.item.scheduledDateUtc,
                                ),
                          ),
                  child: Text(l10n.skipButton),
                ),
                FilledButton(
                  key: Key('postOccurrence_${rule.id}_$_dateKey'),
                  onPressed: _isBusy
                      ? null
                      : () => _handle(
                            () => ref.read(recurringOccurrenceRepositoryProvider).postOccurrence(
                                  ruleId: rule.id,
                                  scheduledDateUtc: widget.item.scheduledDateUtc,
                                ),
                          ),
                  child: Text(l10n.postButton),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Create (no [existingRule]) or edit (an active [existingRule]) a
/// recurring rule. [RecurringRuleKind] is chosen only when creating --
/// see `RecurringRuleRepository.updateRule`'s doc comment for why it's
/// permanently fixed afterward.
class _RuleDialog extends ConsumerStatefulWidget {
  const _RuleDialog({this.existingRule});
  final RecurringRuleRow? existingRule;

  @override
  ConsumerState<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends ConsumerState<_RuleDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _intervalController;
  late final TextEditingController _noteController;
  late RecurringRuleKind _kind;
  late RecurrenceFrequency _frequency;
  String? _accountId;
  String? _destinationAccountId;
  String? _categoryId;
  Money? _parsedAmount;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _notificationsEnabled = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    final RecurringRuleRow? existing = widget.existingRule;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _intervalController = TextEditingController(text: '${existing?.interval ?? 1}');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _kind = existing == null ? RecurringRuleKind.expense : RecurringRuleKind.values.byName(existing.kind);
    _frequency = existing == null
        ? RecurrenceFrequency.monthly
        : RecurrenceFrequency.values.byName(existing.frequency);
    _accountId = existing?.accountId;
    _destinationAccountId = existing?.destinationAccountId;
    _categoryId = existing?.categoryId;
    _startDate = existing?.startDate ?? DateTime.now().toUtc();
    _endDate = existing?.endDate;
    _notificationsEnabled = existing?.notificationsEnabled ?? false;
    // `MoneyTextField` only calls `onParsed` in response to the user
    // typing (see its `onChanged: _tryParse`) or a currency change via
    // `didUpdateWidget` -- it never parses its own `initialValue` on
    // first build. Without seeding `_parsedAmount` here, editing an
    // existing rule without touching the amount field left it `null`,
    // which made `_submit` silently return at its
    // `if (amount == null || ...) return;` guard -- Save appeared to do
    // nothing and the dialog never closed.
    _parsedAmount =
        existing == null ? null : Money.fromMinorUnits(existing.amountMinorUnits, existing.currencyCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (isStart ? _startDate : _endDate) ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  /// Handles the "Remind me" switch. Per Beta 1 Task 4B correction 3:
  /// notification permission is requested ONLY here -- the direct,
  /// synchronous result of the user turning this toggle on -- never at
  /// app startup, during reconciliation, or merely because this dialog
  /// opened (`initState` above only READS the persisted value, it never
  /// calls this). Turning the toggle off never needs permission at all.
  ///
  /// If permission isn't granted, reverts to off (per the user's stated
  /// preference: persisted state should reflect actually-usable
  /// behavior) and shows a concise, one-time message -- no crash, no
  /// repeated automatic prompt (the OS itself won't re-prompt once
  /// denied; this handler only ever asks again if the user taps the
  /// switch on again themselves).
  Future<void> _onNotificationsToggled(bool wantsEnabled) async {
    if (!wantsEnabled) {
      setState(() => _notificationsEnabled = false);
      return;
    }
    final NotificationScheduler scheduler = ref.read(notificationSchedulerProvider);
    final NotificationPermissionStatus status = await scheduler.requestPermission();
    if (!mounted) return;
    if (status == NotificationPermissionStatus.granted) {
      setState(() => _notificationsEnabled = true);
    } else {
      setState(() => _notificationsEnabled = false);
      final AppLocalizations l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsPermissionDeniedMessage)),
      );
    }
  }

  /// Destination accounts eligible for a transfer FROM
  /// [sourceAccountId]: not the source account itself, and the same
  /// currency -- Beta 1 Task 4A does not support FX/cross-currency
  /// recurring transfers (see
  /// `RecurringRuleRepository._validateAccounts`, which enforces this
  /// independently of this filter and remains the authoritative check;
  /// this is convenience-only, same precedent as
  /// `_DestinationAccountDropdown` in `add_transaction_screen.dart`
  /// (ADR-019)). [accounts] is already profile-scoped, active-only
  /// via `accountsProvider`, so no further eligibility filtering is
  /// needed here.
  List<AccountRow> _eligibleDestinationAccounts(List<AccountRow> accounts, String? sourceAccountId) {
    AccountRow? source;
    for (final AccountRow candidate in accounts) {
      if (candidate.id == sourceAccountId) {
        source = candidate;
        break;
      }
    }
    // Copied to a non-nullable local before the closure below -- Dart
    // does not carry null-promotion of a captured variable into a
    // closure.
    final AccountRow? sourceAccount = source;
    if (sourceAccount == null) return const <AccountRow>[];
    return accounts
        .where((a) => a.id != sourceAccount.id && a.currencyCode == sourceAccount.currencyCode)
        .toList(growable: false);
  }

  Future<void> _submit(List<AccountRow> accounts) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final Money? amount = _parsedAmount;
    final String? accountId = _accountId;
    final DateTime? startDate = _startDate;
    if (amount == null || accountId == null || startDate == null) return;
    if (_kind == RecurringRuleKind.transfer && _destinationAccountId == null) {
      setState(() => _errorMessage = l10n.chooseDestinationAccount);
      return;
    }
    final int? interval = int.tryParse(_intervalController.text.trim());
    if (interval == null) return;

    setState(() => _isSaving = true);
    try {
      final String note = _noteController.text.trim();
      if (_isEditing) {
        await ref.read(recurringRuleRepositoryProvider).updateRule(
              id: widget.existingRule!.id,
              name: _nameController.text,
              amount: amount,
              accountId: accountId,
              destinationAccountId: _kind == RecurringRuleKind.transfer
                  ? Value<String?>(_destinationAccountId)
                  : const Value<String?>.absent(),
              categoryId: _kind == RecurringRuleKind.transfer
                  ? const Value<String?>(null)
                  : Value<String?>(_categoryId),
              note: Value<String?>(note.isEmpty ? null : note),
              frequency: _frequency,
              interval: interval,
              startDate: startDate,
              endDate: Value<DateTime?>(_endDate),
              notificationsEnabled: Value<bool>(_notificationsEnabled),
            );
      } else {
        final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
        if (profile == null) return;
        await ref.read(recurringRuleRepositoryProvider).createRule(
              profileId: profile.id,
              kind: _kind,
              name: _nameController.text,
              amount: amount,
              accountId: accountId,
              destinationAccountId: _kind == RecurringRuleKind.transfer ? _destinationAccountId : null,
              categoryId: _kind == RecurringRuleKind.transfer ? null : _categoryId,
              note: note.isEmpty ? null : note,
              frequency: _frequency,
              interval: interval,
              startDate: startDate,
              endDate: _endDate,
              notificationsEnabled: _notificationsEnabled,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on CurrencyMismatchException catch (e) {
      // Belt-and-braces: the destination dropdown already only offers
      // same-currency accounts (see `_eligibleDestinationAccounts`
      // above), but the repository enforces this independently -- see
      // `RecurringRuleRepository._validateAccounts` -- so surface its
      // rejection cleanly rather than letting it crash the dialog. This
      // is exactly the bug manual Android testing found: Save appeared
      // unresponsive because this exception was previously unhandled.
      setState(() {
        _errorMessage =
            l10n.transfersCrossCurrencyNotSupportedMessage(e.currencyCodeA, e.currencyCodeB);
      });
    } on InvalidRecurringRuleAmountException catch (e) {
      setState(() => _errorMessage = e.toString());
    } on InvalidRecurringRuleNameException catch (e) {
      setState(() => _errorMessage = e.toString());
    } on RecurringRuleNotFoundException catch (e) {
      setState(() => _errorMessage = e.toString());
    } on ArgumentError catch (e) {
      // Covers the repository's own input-validation checks that use
      // `ArgumentError` (interval, end date, same source/destination
      // account, unsupported currency) -- see
      // `RecurringRuleRepository._validateAccounts`/`_validateInterval`/
      // `_validateDateRange`. Deliberately NOT a bare `catch` -- an
      // unexpected error (a real bug) should still surface as an
      // unhandled exception rather than being swallowed here.
      setState(() => _errorMessage = (e.message ?? 'Invalid value.').toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final List<AccountRow> accounts = accountsAsync.valueOrNull ?? const <AccountRow>[];
    final AccountRow? selectedAccount =
        accounts.where((a) => a.id == _accountId).cast<AccountRow?>().firstWhere(
              (a) => true,
              orElse: () => accounts.isEmpty ? null : accounts.first,
            );
    final String amountCurrency = selectedAccount?.currencyCode ?? 'JPY';
    final String categoryType = _kind == RecurringRuleKind.income ? 'income' : 'expense';
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider(categoryType));
    final List<AccountRow> eligibleDestinationAccounts = _kind == RecurringRuleKind.transfer
        ? _eligibleDestinationAccounts(accounts, _accountId)
        : const <AccountRow>[];
    // Only meaningful once a source account is actually chosen -- before
    // that, the source dropdown's own "Choose an account." validator is
    // what blocks Save, not this.
    final bool noEligibleDestination =
        _kind == RecurringRuleKind.transfer && _accountId != null && eligibleDestinationAccounts.isEmpty;
    final Widget? destinationField = _kind != RecurringRuleKind.transfer || _accountId == null
        ? null
        : eligibleDestinationAccounts.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.noSameCurrencyDestinationMessage,
                  key: const Key('noEligibleDestinationMessage'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            : DropdownButtonFormField<String>(
                key: const Key('recurringDestinationAccountDropdown'),
                initialValue: eligibleDestinationAccounts.any((a) => a.id == _destinationAccountId)
                    ? _destinationAccountId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.destinationAccountLabel),
                items: <DropdownMenuItem<String>>[
                  for (final AccountRow account in eligibleDestinationAccounts)
                    DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        '${account.name} (${account.currencyCode})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? v) => setState(() => _destinationAccountId = v),
                validator: (String? v) => v == null ? l10n.chooseDestinationAccount : null,
              );

    return AlertDialog(
      title: Text(_isEditing ? l10n.editRecurringRuleTitle : l10n.newRecurringRuleTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!_isEditing)
                DropdownButtonFormField<RecurringRuleKind>(
                  key: const Key('recurringKindDropdown'),
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.recurringKindFieldLabel),
                  items: <DropdownMenuItem<RecurringRuleKind>>[
                    for (final RecurringRuleKind kind in RecurringRuleKind.values)
                      DropdownMenuItem<RecurringRuleKind>(
                        value: kind,
                        child: Text(_kindLabel(l10n, kind), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (RecurringRuleKind? v) => setState(() {
                    _kind = v ?? _kind;
                    _categoryId = null;
                    _destinationAccountId = null;
                  }),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${l10n.recurringKindFieldLabel}: ${_kindLabel(l10n, _kind)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              TextFormField(
                key: const Key('recurringNameField'),
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.recurringRuleNameLabel),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterRecurringRuleNameMessage : null,
              ),
              DropdownButtonFormField<String>(
                key: const Key('recurringAccountDropdown'),
                initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      _kind == RecurringRuleKind.transfer ? l10n.sourceAccountLabel : l10n.accountLabel,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final AccountRow account in accounts)
                    DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        '${account.name} (${account.currencyCode})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? v) => setState(() {
                  _accountId = v;
                  // Requirement 2: if the previously selected destination
                  // is no longer eligible under the new source account
                  // (different account, different currency), clear it --
                  // never leave a stale, now-invalid destination selected
                  // just because the dropdown itself re-renders without
                  // it as an option.
                  final List<AccountRow> stillEligible = _eligibleDestinationAccounts(accounts, v);
                  if (_destinationAccountId != null &&
                      !stillEligible.any((a) => a.id == _destinationAccountId)) {
                    _destinationAccountId = null;
                  }
                }),
                validator: (String? v) => v == null ? l10n.chooseAccountMessage : null,
              ),
              if (destinationField != null) destinationField,
              if (_kind != RecurringRuleKind.transfer)
                categoriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (Object e, StackTrace st) => const SizedBox.shrink(),
                  data: (List<CategoryRow> categories) => DropdownButtonFormField<String?>(
                    key: const Key('recurringCategoryDropdown'),
                    initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.categoryOptionalLabel),
                    items: <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(value: null, child: Text(l10n.noneOptionLabel)),
                      for (final CategoryRow category in categories)
                        DropdownMenuItem<String?>(
                          value: category.id,
                          child: Text(category.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (String? v) => setState(() => _categoryId = v),
                  ),
                ),
              MoneyTextField(
                key: const Key('recurringAmountField'),
                currencyCode: amountCurrency,
                label: l10n.amountLabel,
                initialValue: widget.existingRule == null
                    ? null
                    : Money.fromMinorUnits(widget.existingRule!.amountMinorUnits, amountCurrency)
                        .toMajorUnitsString(),
                onParsed: (Money? m) => _parsedAmount = m,
              ),
              DropdownButtonFormField<RecurrenceFrequency>(
                key: const Key('recurringFrequencyDropdown'),
                initialValue: _frequency,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.frequencyLabel),
                items: <DropdownMenuItem<RecurrenceFrequency>>[
                  for (final RecurrenceFrequency freq in RecurrenceFrequency.values)
                    DropdownMenuItem<RecurrenceFrequency>(
                      value: freq,
                      child: Text(_frequencyLabel(l10n, freq), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (RecurrenceFrequency? v) => setState(() => _frequency = v ?? _frequency),
              ),
              TextFormField(
                key: const Key('recurringIntervalField'),
                controller: _intervalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.intervalLabel),
                validator: (String? v) {
                  final int? parsed = int.tryParse((v ?? '').trim());
                  if (parsed == null || parsed < 1) return l10n.enterWholeNumberMessage;
                  return null;
                },
              ),
              SwitchListTile(
                key: const Key('recurringNotificationsToggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.remindMeLabel),
                subtitle: Text(l10n.remindMeSubtitle),
                value: _notificationsEnabled,
                onChanged: (bool v) => unawaited(_onNotificationsToggled(v)),
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('pickRecurringStartDate'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _startDate == null
                      ? l10n.chooseStartDateMessage
                      : '${l10n.startDateLabel}: ${DateFormat.yMMMd().format(_startDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () => _pickDate(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _endDate == null
                      ? l10n.noEndDateMessage
                      : '${l10n.endDateLabel}: ${DateFormat.yMMMd().format(_endDate!)}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: <Widget>[
                    TextButton(
                      key: const Key('pickRecurringEndDate'),
                      onPressed: () => _pickDate(isStart: false),
                      child: Text(l10n.chooseButton),
                    ),
                    if (_endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.clearEndDateTooltip,
                        onPressed: () => setState(() => _endDate = null),
                      ),
                  ],
                ),
              ),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(labelText: l10n.noteOptionalLabel),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  key: const Key('recurringFormErrorMessage'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
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
          key: const Key('saveRecurringRule'),
          onPressed: (_isSaving || noEligibleDestination) ? null : () => _submit(accounts),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
