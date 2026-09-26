import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/cheque_repository.dart' show ChequeRowX;
import '../../../core/database/repositories/cheque_validation_exception.dart';
import '../../../core/finance/cheque_direction.dart';
import '../../../core/finance/cheque_status.dart';
import '../../../core/money/currency_mismatch_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../../accounts/presentation/account_providers.dart';
import 'cheque_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Checkpoint N: the Cheques/Checks list -- every cheque (issued or
/// received) for the current profile, plus a way to record a new one.
/// Reached ONLY from More's "Cheques" row -- see `MoreScreen` and
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.16.
class ChequesScreen extends ConsumerWidget {
  const ChequesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<ChequeRow>> chequesAsync = ref.watch(activeChequesProvider);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(allAccountsProvider);
    final AsyncValue<List<ChequeBookRow>> chequeBooksAsync = ref.watch(allChequeBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chequesTitle)),
      body: chequesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text(l10n.couldNotLoadCheques(e.toString()))),
        data: (List<ChequeRow> cheques) {
          if (cheques.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noChequesYetMessage, textAlign: TextAlign.center),
              ),
            );
          }
          final Map<String, AccountRow> accountsById = <String, AccountRow>{
            for (final AccountRow account in accountsAsync.valueOrNull ?? const <AccountRow>[])
              account.id: account,
          };
          final Map<String, ChequeBookRow> chequeBooksById = <String, ChequeBookRow>{
            for (final ChequeBookRow book in chequeBooksAsync.valueOrNull ?? const <ChequeBookRow>[])
              book.id: book,
          };
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              for (final ChequeRow cheque in cheques)
                _ChequeListTile(
                  cheque: cheque,
                  account: accountsById[cheque.accountId],
                  chequeBook: cheque.chequeBookId == null ? null : chequeBooksById[cheque.chequeBookId],
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addChequeFab'),
        onPressed: () => _showRecordChequeChooser(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showRecordChequeChooser(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const Key('recordIssuedChequeOption'),
              leading: const Icon(Icons.call_made),
              title: Text(l10n.recordIssuedChequeTitle),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog<void>(context: context, builder: (_) => const _RecordIssuedChequeDialog());
              },
            ),
            ListTile(
              key: const Key('recordReceivedChequeOption'),
              leading: const Icon(Icons.call_received),
              title: Text(l10n.recordReceivedChequeTitle),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog<void>(context: context, builder: (_) => const _RecordReceivedChequeDialog());
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The localized, never-color-only status word for [status] -- shared by
/// the list tile and the detail screen.
String chequeStatusLabel(AppLocalizations l10n, ChequeStatus status) => switch (status) {
      ChequeStatus.pending => l10n.chequeStatusPending,
      ChequeStatus.cleared => l10n.chequeStatusCleared,
      ChequeStatus.bounced => l10n.chequeStatusBounced,
      ChequeStatus.stopped => l10n.chequeStatusStopped,
      ChequeStatus.cancelled => l10n.chequeStatusCancelled,
    };

Color chequeStatusColor(ColorScheme colors, ChequeStatus status) => switch (status) {
      ChequeStatus.pending => colors.onSurfaceVariant,
      ChequeStatus.cleared => colors.primary,
      ChequeStatus.bounced => colors.error,
      ChequeStatus.stopped => colors.error,
      ChequeStatus.cancelled => colors.onSurfaceVariant,
    };

/// Resolves [accountId]'s currency for the [MoneyTextField] in either
/// record dialog, defaulting to the first registry currency until an
/// account is chosen -- avoids a dependency on `package:collection`'s
/// `firstOrNull` for a single-element lookup.
String _currencyCodeForSelectedAccount(List<AccountRow> accounts, String? accountId) {
  if (accountId == null) return CurrencyRegistry.seed.first.code;
  for (final AccountRow account in accounts) {
    if (account.id == accountId) return account.currencyCode;
  }
  return CurrencyRegistry.seed.first.code;
}

class _ChequeListTile extends StatelessWidget {
  const _ChequeListTile({required this.cheque, required this.account, required this.chequeBook});

  final ChequeRow cheque;
  final AccountRow? account;
  final ChequeBookRow? chequeBook;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ChequeDirection direction = cheque.directionValue;
    final ChequeStatus status = cheque.statusValue;
    final String sign = direction == ChequeDirection.issued ? '-' : '+';
    final String accountLabel = account?.name ?? l10n.unknownAccountLabel;

    return AppCard(
      bordered: true,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: EdgeInsets.zero,
      child: ListTile(
        key: Key('chequeTile_${cheque.id}'),
        leading: CircleAvatar(
          backgroundColor: colors.surfaceContainerHighest,
          child: Icon(
            direction == ChequeDirection.issued ? Icons.call_made : Icons.call_received,
            color: colors.onSurfaceVariant,
          ),
        ),
        title: Text(
          cheque.counterpartyName,
          style: context.appTypography.cardTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${l10n.chequeNumberLabel} ${cheque.chequeNumber} · $accountLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.appTypography.secondaryBody,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('$sign${_formatter.format(cheque.amount)}'),
            Text(
              chequeStatusLabel(l10n, status),
              style: TextStyle(color: chequeStatusColor(colors, status), fontSize: 12),
            ),
          ],
        ),
        onTap: () => context.push(AppRoutes.chequeDetail(cheque.id)),
      ),
    );
  }
}

/// Shared account picker for both record dialogs -- restricted to
/// [chequeEligibleAccountsProvider] (asset, bank/savings, active), never
/// a name-heuristic. `isExpanded: true` matches `add_transaction_screen
/// .dart`'s own account dropdown, for the same long-name-ellipsis reason.
class _EligibleAccountDropdown extends ConsumerWidget {
  const _EligibleAccountDropdown({required this.accountId, required this.onChanged});

  final String? accountId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(chequeEligibleAccountsProvider);
    final List<AccountRow> accounts = accountsAsync.valueOrNull ?? const <AccountRow>[];
    return DropdownButtonFormField<String>(
      key: const Key('chequeAccountDropdown'),
      isExpanded: true,
      initialValue: accounts.any((AccountRow a) => a.id == accountId) ? accountId : null,
      decoration: InputDecoration(labelText: l10n.accountLabel),
      items: <DropdownMenuItem<String>>[
        for (final AccountRow account in accounts)
          DropdownMenuItem<String>(
            value: account.id,
            child: Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (String? v) => v == null ? l10n.selectAccountMessage : null,
      onChanged: onChanged,
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.date,
    required this.onPick,
    this.fieldKey,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPick;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: fieldKey,
      contentPadding: EdgeInsets.zero,
      title: Text(date == null ? label : '$label: ${DateFormat.yMMMd().format(date!)}'),
      trailing: TextButton(
        onPressed: () async {
          final DateTime now = DateTime.now();
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: date ?? now,
            firstDate: DateTime(now.year - 20),
            lastDate: DateTime(now.year + 5),
          );
          if (picked != null) onPick(picked);
        },
        child: Text(AppLocalizations.of(context).chooseButton),
      ),
    );
  }
}

/// Checkpoint N: minimal chequebook creation, reached inline from the
/// Record Issued Cheque dialog's chequebook picker -- see
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.16's "minimal
/// cheque-book UI" scope (no separate route, no printing/MICR/bank
/// sync). Returns the new chequebook's id via [Navigator.pop] so the
/// caller can immediately re-select it.
class _CreateChequeBookDialog extends ConsumerStatefulWidget {
  const _CreateChequeBookDialog({required this.accountId});

  final String accountId;

  @override
  ConsumerState<_CreateChequeBookDialog> createState() => _CreateChequeBookDialogState();
}

class _CreateChequeBookDialogState extends ConsumerState<_CreateChequeBookDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _startingNumberController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _labelController.dispose();
    _startingNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      final String id = await ref.read(chequeBookRepositoryProvider).createChequeBook(
            profileId: profile.id,
            accountId: widget.accountId,
            label: _labelController.text,
            startingNumber: _startingNumberController.text,
          );
      if (mounted) Navigator.of(context).pop(id);
    } on ChequeValidationException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newChequeBookDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const Key('chequeBookLabelField'),
              controller: _labelController,
              decoration: InputDecoration(labelText: l10n.chequeBookLabelField),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? l10n.enterChequeBookLabelMessage : null,
            ),
            TextFormField(
              key: const Key('chequeBookStartingNumberField'),
              controller: _startingNumberController,
              decoration: InputDecoration(labelText: l10n.startingChequeNumberOptionalField),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
          key: const Key('saveChequeBook'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _RecordIssuedChequeDialog extends ConsumerStatefulWidget {
  const _RecordIssuedChequeDialog();

  @override
  ConsumerState<_RecordIssuedChequeDialog> createState() => _RecordIssuedChequeDialogState();
}

class _RecordIssuedChequeDialogState extends ConsumerState<_RecordIssuedChequeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _chequeNumberController = TextEditingController();
  final TextEditingController _payeeController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  String? _accountId;
  String? _chequeBookId;
  Money? _parsedAmount;
  DateTime _issueDate = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _chequeNumberController.dispose();
    _payeeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _createChequeBookInline() async {
    final String? accountId = _accountId;
    if (accountId == null) return;
    final String? newId = await showDialog<String>(
      context: context,
      builder: (_) => _CreateChequeBookDialog(accountId: accountId),
    );
    if (newId != null) setState(() => _chequeBookId = newId);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String? accountId = _accountId;
    final String? chequeBookId = _chequeBookId;
    final Money? amount = _parsedAmount;
    if (accountId == null || chequeBookId == null || amount == null) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      await ref.read(chequeRepositoryProvider).recordIssued(
            profileId: profile.id,
            accountId: accountId,
            chequeBookId: chequeBookId,
            chequeNumber: _chequeNumberController.text,
            amount: amount,
            payeeName: _payeeController.text,
            issueDateUtc: _issueDate.toUtc(),
            memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ChequeValidationException catch (e) {
      setState(() => _errorMessage = e.message);
    } on CurrencyMismatchException catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<AccountRow> allAccounts = ref.watch(allAccountsProvider).valueOrNull ?? const <AccountRow>[];
    final String currencyCode = _currencyCodeForSelectedAccount(allAccounts, _accountId);
    final List<ChequeBookRow> chequeBooks = _accountId == null
        ? const <ChequeBookRow>[]
        : ref.watch(activeChequeBooksForAccountProvider(_accountId!)).valueOrNull ??
            const <ChequeBookRow>[];

    return AlertDialog(
      title: Text(l10n.recordIssuedChequeTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _EligibleAccountDropdown(
                accountId: _accountId,
                onChanged: (String? v) => setState(() {
                  _accountId = v;
                  _chequeBookId = null;
                }),
              ),
              DropdownButtonFormField<String>(
                key: const Key('chequeBookDropdown'),
                isExpanded: true,
                initialValue: chequeBooks.any((ChequeBookRow b) => b.id == _chequeBookId)
                    ? _chequeBookId
                    : null,
                decoration: InputDecoration(labelText: l10n.chequeBookLabelField),
                items: <DropdownMenuItem<String>>[
                  for (final ChequeBookRow book in chequeBooks)
                    DropdownMenuItem<String>(value: book.id, child: Text(book.label)),
                ],
                onChanged: (String? v) => setState(() => _chequeBookId = v),
                validator: (String? v) => v == null ? l10n.selectChequeBookMessage : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('createChequeBookInline'),
                  onPressed: _accountId == null ? null : _createChequeBookInline,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newChequeBookDialogTitle),
                ),
              ),
              TextFormField(
                key: const Key('chequeNumberField'),
                controller: _chequeNumberController,
                decoration: InputDecoration(labelText: l10n.chequeNumberFieldLabel),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterChequeNumberMessage : null,
              ),
              MoneyTextField(
                key: const Key('chequeAmountField'),
                currencyCode: currencyCode,
                label: l10n.amountLabel,
                onParsed: (Money? m) => _parsedAmount = m,
              ),
              TextFormField(
                key: const Key('payeeField'),
                controller: _payeeController,
                decoration: InputDecoration(labelText: l10n.payeeFieldLabel),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterPayeeMessage : null,
              ),
              _DatePickerRow(
                fieldKey: const Key('issueDatePicker'),
                label: l10n.issueDateLabel,
                date: _issueDate,
                onPick: (DateTime d) => setState(() => _issueDate = d),
              ),
              TextFormField(
                key: const Key('chequeMemoField'),
                controller: _memoController,
                decoration: InputDecoration(labelText: l10n.memoOptionalFieldLabel),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
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
          key: const Key('saveIssuedCheque'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _RecordReceivedChequeDialog extends ConsumerStatefulWidget {
  const _RecordReceivedChequeDialog();

  @override
  ConsumerState<_RecordReceivedChequeDialog> createState() => _RecordReceivedChequeDialogState();
}

class _RecordReceivedChequeDialogState extends ConsumerState<_RecordReceivedChequeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _chequeNumberController = TextEditingController();
  final TextEditingController _payerController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  String? _accountId;
  Money? _parsedAmount;
  DateTime _issueDate = DateTime.now();
  DateTime _receivedDate = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _chequeNumberController.dispose();
    _payerController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String? accountId = _accountId;
    final Money? amount = _parsedAmount;
    if (accountId == null || amount == null) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      await ref.read(chequeRepositoryProvider).recordReceived(
            profileId: profile.id,
            accountId: accountId,
            chequeNumber: _chequeNumberController.text,
            amount: amount,
            payerName: _payerController.text,
            issueDateUtc: _issueDate.toUtc(),
            receivedDateUtc: _receivedDate.toUtc(),
            memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ChequeValidationException catch (e) {
      setState(() => _errorMessage = e.message);
    } on CurrencyMismatchException catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<AccountRow> allAccounts = ref.watch(allAccountsProvider).valueOrNull ?? const <AccountRow>[];
    final String currencyCode = _currencyCodeForSelectedAccount(allAccounts, _accountId);

    return AlertDialog(
      title: Text(l10n.recordReceivedChequeTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _EligibleAccountDropdown(
                accountId: _accountId,
                onChanged: (String? v) => setState(() => _accountId = v),
              ),
              TextFormField(
                key: const Key('receivedChequeNumberField'),
                controller: _chequeNumberController,
                decoration: InputDecoration(labelText: l10n.chequeNumberFieldLabel),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterChequeNumberMessage : null,
              ),
              MoneyTextField(
                key: const Key('receivedChequeAmountField'),
                currencyCode: currencyCode,
                label: l10n.amountLabel,
                onParsed: (Money? m) => _parsedAmount = m,
              ),
              TextFormField(
                key: const Key('payerField'),
                controller: _payerController,
                decoration: InputDecoration(labelText: l10n.payerFieldLabel),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterPayerMessage : null,
              ),
              _DatePickerRow(
                fieldKey: const Key('receivedIssueDatePicker'),
                label: l10n.issueDateLabel,
                date: _issueDate,
                onPick: (DateTime d) => setState(() => _issueDate = d),
              ),
              _DatePickerRow(
                fieldKey: const Key('receivedDatePicker'),
                label: l10n.receivedDateLabel,
                date: _receivedDate,
                onPick: (DateTime d) => setState(() => _receivedDate = d),
              ),
              TextFormField(
                key: const Key('receivedChequeMemoField'),
                controller: _memoController,
                decoration: InputDecoration(labelText: l10n.memoOptionalFieldLabel),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
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
          key: const Key('saveReceivedCheque'),
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
