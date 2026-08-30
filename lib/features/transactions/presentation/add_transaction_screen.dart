import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/money/currency_mismatch_exception.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// Add Expense / Add Income / Transfer — one screen, driven by
/// [initialType] ('expense' | 'income' | 'transfer'), per
/// `docs/02_SCREEN_CATALOG.md` items 9-11. `type` is fixed for the
/// lifetime of one screen instance; switching type re-opens the Add
/// sheet rather than mutating the form in place, which keeps the form
/// state simple and matches how the sheet in
/// `add_transaction_sheet.dart` presents the three as distinct choices.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({required this.initialType, super.key});

  final String? initialType;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _type = <String>['expense', 'income', 'transfer'].contains(widget.initialType)
      ? widget.initialType!
      : 'expense';

  String? _accountId;
  String? _destinationAccountId;
  String? _categoryId;
  String? _note;
  Money? _amount;
  DateTime _occurredAt = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isTransfer => _type == 'transfer';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(_type))),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load accounts: $e')),
        data: (List<AccountRow> accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Add an account first (Profile → Accounts) before recording money.'),
              ),
            );
          }
          _accountId ??= accounts.first.id;
          final AccountRow? selectedAccount = _findAccount(accounts, _accountId);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  decoration: InputDecoration(labelText: _isTransfer ? 'From account' : 'Account'),
                  items: <DropdownMenuItem<String>>[
                    for (final AccountRow account in accounts)
                      DropdownMenuItem<String>(
                        value: account.id,
                        child: Text('${account.name} (${account.currencyCode})'),
                      ),
                  ],
                  onChanged: (String? id) => setState(() {
                    _accountId = id;
                    if (_destinationAccountId == _accountId) _destinationAccountId = null;
                  }),
                ),
                if (_isTransfer) ...<Widget>[
                  const SizedBox(height: 16),
                  _DestinationAccountDropdown(
                    accounts: accounts,
                    sourceAccountId: _accountId,
                    value: _destinationAccountId,
                    onChanged: (String? id) => setState(() => _destinationAccountId = id),
                  ),
                ],
                if (!_isTransfer) ...<Widget>[
                  const SizedBox(height: 16),
                  _CategoryDropdown(
                    type: _type,
                    value: _categoryId,
                    onChanged: (String? id) => setState(() => _categoryId = id),
                  ),
                ],
                const SizedBox(height: 16),
                if (selectedAccount != null)
                  MoneyTextField(
                    currencyCode: selectedAccount.currencyCode,
                    onParsed: (Money? amount) => setState(() => _amount = amount),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                  onChanged: (String value) => _note = value,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(
                    '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-'
                    '${_occurredAt.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...<Widget>[
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _isSaving ? null : () => _submit(accounts),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  AccountRow? _findAccount(List<AccountRow> accounts, String? id) {
    for (final AccountRow a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _occurredAt = picked);
  }

  Future<void> _submit(List<AccountRow> accounts) async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_amount == null) {
      setState(() => _errorMessage = 'Enter a valid amount.');
      return;
    }
    if (_isTransfer && _destinationAccountId == null) {
      setState(() => _errorMessage = 'Choose a destination account.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      final TransactionRepository repo = ref.read(transactionRepositoryProvider);
      final DateTime occurredAtUtc = _occurredAt.toUtc();

      switch (_type) {
        case 'expense':
          await repo.recordExpense(
            profileId: profile.id,
            accountId: _accountId!,
            amount: _amount!,
            categoryId: _categoryId,
            note: _note,
            occurredAtUtc: occurredAtUtc,
          );
        case 'income':
          await repo.recordIncome(
            profileId: profile.id,
            accountId: _accountId!,
            amount: _amount!,
            categoryId: _categoryId,
            note: _note,
            occurredAtUtc: occurredAtUtc,
          );
        case 'transfer':
          await repo.recordTransfer(
            profileId: profile.id,
            sourceAccountId: _accountId!,
            destinationAccountId: _destinationAccountId!,
            amount: _amount!,
            note: _note,
            occurredAtUtc: occurredAtUtc,
          );
      }
      if (mounted) Navigator.of(context).pop();
    } on CurrencyMismatchException catch (e) {
      // Belt-and-braces: the destination dropdown already only offers
      // same-currency accounts (ADR-019), but the repository enforces
      // this independently — see transaction_repository.dart — so
      // surface its rejection cleanly rather than letting it crash.
      setState(() {
        _errorMessage = "Transfers between different currencies aren't supported yet "
            '(${e.currencyCodeA} → ${e.currencyCodeB}).';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _titleFor(String type) => switch (type) {
        'income' => 'Add income',
        'transfer' => 'Transfer',
        _ => 'Add expense',
      };
}

class _DestinationAccountDropdown extends StatelessWidget {
  const _DestinationAccountDropdown({
    required this.accounts,
    required this.sourceAccountId,
    required this.value,
    required this.onChanged,
  });

  final List<AccountRow> accounts;
  final String? sourceAccountId;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    AccountRow? source;
    for (final AccountRow candidate in accounts) {
      if (candidate.id == sourceAccountId) {
        source = candidate;
        break;
      }
    }
    // ADR-019 (Decision 5): Beta 0 supports same-currency transfers only.
    // Enforced here at the form layer by only ever offering same-currency
    // destinations — not just relying on the repository to reject an
    // invalid choice after the fact.
    //
    // `source` is copied to a non-nullable local before the closure below
    // because Dart does not carry null-promotion of a captured variable
    // into a closure.
    final List<AccountRow> eligible;
    final AccountRow? sourceAccount = source;
    if (sourceAccount == null) {
      eligible = const <AccountRow>[];
    } else {
      eligible = accounts
          .where((a) => a.id != sourceAccount.id && a.currencyCode == sourceAccount.currencyCode)
          .toList(growable: false);
    }

    if (source != null && eligible.isEmpty) {
      return Text(
        'No other ${source.currencyCode} account to transfer to yet. '
        'Cross-currency transfers are not supported in this version.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: eligible.any((a) => a.id == value) ? value : null,
      decoration: const InputDecoration(labelText: 'To account'),
      items: <DropdownMenuItem<String>>[
        for (final AccountRow account in eligible)
          DropdownMenuItem<String>(value: account.id, child: Text(account.name)),
      ],
      onChanged: onChanged,
      validator: (String? v) => v == null ? 'Choose a destination account.' : null,
    );
  }
}

class _CategoryDropdown extends ConsumerWidget {
  const _CategoryDropdown({required this.type, required this.value, required this.onChanged});

  final String type;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider(type));
    return categoriesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (Object e, StackTrace st) => Text('Could not load categories: $e'),
      data: (List<CategoryRow> categories) {
        return DropdownButtonFormField<String>(
          initialValue: categories.any((c) => c.id == value) ? value : null,
          decoration: const InputDecoration(labelText: 'Category (optional)'),
          items: <DropdownMenuItem<String>>[
            for (final CategoryRow category in categories)
              DropdownMenuItem<String>(value: category.id, child: Text(category.name)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
