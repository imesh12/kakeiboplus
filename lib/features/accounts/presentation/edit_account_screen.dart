import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'account_form_fields.dart';
import 'account_providers.dart';

/// Resolves [accountId] to a live [AccountRow] and hands it to
/// [_EditAccountBody] -- V1 Accounts Detail + Edit Checkpoint. Mirrors
/// `EditTransactionScreen`'s own id-to-row resolution shape (loading/
/// error/missing-row states as their own `Scaffold`, so the AppBar title
/// is present even before the row resolves), the same convention
/// `GoalDetailScreen`/`TransactionDetailScreen`/`AccountDetailScreen`
/// already use for a possibly-missing id.
///
/// Unlike `EditTransactionScreen` (which reuses `AddTransactionScreen`
/// wholesale for its form), this is its own small screen: account
/// editing has a much smaller, structurally different field set (no
/// amount/date/note) and a hard extra rule -- currency must never be
/// editable here -- that doesn't fit naturally into the Add Account
/// dialog's chrome. The actual name/type fields are still shared via
/// [AccountIdentityFormFields] rather than duplicated -- see that
/// widget's doc comment.
class EditAccountScreen extends ConsumerWidget {
  const EditAccountScreen({required this.accountId, super.key});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<AccountRow?> accountAsync = ref.watch(accountByIdProvider(accountId));

    return accountAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.editAccountTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace st) => Scaffold(
        appBar: AppBar(title: Text(l10n.editAccountTitle)),
        body: Center(child: Text(l10n.couldNotLoadAccountDetail('$e'))),
      ),
      data: (AccountRow? account) {
        if (account == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.editAccountTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.accountNoLongerAvailableMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        // Keyed on the account's id so a save (which doesn't itself
        // navigate away -- see `_EditAccountBody._save`) rebuilds this
        // whole subtree with a fresh `TextEditingController` reflecting
        // the just-saved name/type, rather than keeping the pre-edit
        // text alive in stale controller state.
        return _EditAccountBody(key: ValueKey<String>(account.id), account: account);
      },
    );
  }
}

/// The actual edit form -- a full screen (not a dialog, unlike Add
/// Account) so it fits the same push/pop navigation as every other
/// detail/edit pair in this app, and so there's room for the read-only
/// currency explanation below the shared name/type fields.
class _EditAccountBody extends ConsumerStatefulWidget {
  const _EditAccountBody({required this.account, super.key});
  final AccountRow account;

  @override
  ConsumerState<_EditAccountBody> createState() => _EditAccountBodyState();
}

class _EditAccountBodyState extends ConsumerState<_EditAccountBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _type;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _type = widget.account.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Persists only `name`/`type` via `AccountRepository.updateAccount` --
  /// currency, opening balance, id, profileId, and createdAt are never
  /// touched here (see that method's own doc comment for exactly why
  /// currency in particular is excluded). On success, pops back to
  /// `AccountDetailScreen`, which is already watching
  /// `accountByIdProvider` and so reflects the edit immediately -- no
  /// separate "refresh" step is needed. Cancel/back (no call to
  /// [_save]) never reaches the repository at all, so no partial edit is
  /// ever persisted.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(accountRepositoryProvider).updateAccount(
            id: widget.account.id,
            name: _nameController.text.trim(),
            type: _type,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editAccountTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AccountIdentityFormFields(
                  nameController: _nameController,
                  type: _type,
                  onTypeChanged: (String? v) => setState(() => _type = v ?? _type),
                ),
                // Currency: read-only display, never a picker, in this
                // screen -- see `AccountRepository.updateAccount`'s doc
                // comment. `TextFormField` (disabled) rather than plain
                // text so it visually matches the two editable fields
                // above it instead of looking like a stray label.
                TextFormField(
                  initialValue: widget.account.currencyCode,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: l10n.currencySection,
                    helperText: l10n.accountCurrencyLockedMessage,
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
