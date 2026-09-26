import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/account_repository.dart';
import '../../../core/database/repositories/credit_facility_repository.dart'
    show CreditFacilityDetailsRowX;
import '../../../core/finance/financial_account_subtype.dart';
import '../../../core/money/money.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/money_text_field.dart';
import 'account_form_fields.dart';
import 'account_providers.dart';
import 'account_type_presentation.dart';

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
        // Checkpoint O: for a credit-card account, also resolve its
        // credit facility here, synchronously alongside the account --
        // the same "resolve before constructing the body" shape
        // `account` itself already uses, so `_EditAccountBody`'s
        // credit-limit field can seed its `initialValue` once, in
        // `initState`, from an already-known value -- the same
        // precedent `goal_detail_screen.dart`'s own edit-target-amount
        // field establishes -- rather than depending on a stream that
        // may not have delivered by the time that field's `initState`
        // runs.
        //
        // Keyed on the account's id AND (for a credit card) whether the
        // facility has actually arrived yet: `creditFacilityForAccountProvider`
        // collapses its own brief loading gap to `null` (see that
        // provider's doc) -- appending that state to the key means this
        // widget is torn down and rebuilt ONE additional time, the
        // moment the real facility value arrives, rather than ever
        // being stuck with a stale `null` seed. In practice (a local
        // Drift query) that gap is at most one frame, before the user
        // could have typed anything, so the rebuild is unobservable --
        // matching every other `disposeInOrder`/stream-seeding precedent
        // in this app's own doc comments that already accepts this
        // same "instantly-resolving" tradeoff.
        final bool isCreditCard = account.subtypeValue == FinancialAccountSubtype.creditCard;
        final CreditFacilityDetailsRow? creditFacility =
            isCreditCard ? ref.watch(creditFacilityForAccountProvider(account.id)) : null;
        return _EditAccountBody(
          key: ValueKey<String>('${account.id}_${creditFacility?.id ?? "pending"}'),
          account: account,
          initialCreditFacility: creditFacility,
        );
      },
    );
  }
}

/// The actual edit form -- a full screen (not a dialog, unlike Add
/// Account) so it fits the same push/pop navigation as every other
/// detail/edit pair in this app, and so there's room for the read-only
/// currency explanation below the shared name/type fields.
class _EditAccountBody extends ConsumerStatefulWidget {
  const _EditAccountBody({
    required this.account,
    required this.initialCreditFacility,
    super.key,
  });
  final AccountRow account;

  /// Checkpoint O: the account's credit facility at the moment this
  /// widget was constructed -- `null` for every non-credit-card
  /// account, and (very briefly, see `EditAccountScreen`'s own doc)
  /// possibly still `null` for a credit-card account whose facility
  /// hadn't arrived yet on the very first build. Read only once, in
  /// [_EditAccountBodyState.initState] -- this widget is torn down and
  /// rebuilt (see this widget's `key`) the moment a real value arrives,
  /// so [_EditAccountBodyState] never needs to react to this changing
  /// on an already-mounted instance.
  final CreditFacilityDetailsRow? initialCreditFacility;

  @override
  ConsumerState<_EditAccountBody> createState() => _EditAccountBodyState();
}

class _EditAccountBodyState extends ConsumerState<_EditAccountBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _type;
  bool _isSaving = false;

  /// Checkpoint O: the credit-limit field's current parsed value --
  /// `null` for every non-credit-card account (never read by [_save]
  /// in that case). Seeded once, below, from [_EditAccountBody
  /// .initialCreditFacility] -- the same synchronous-seed-in-initState
  /// shape `goal_detail_screen.dart`'s own edit-target-amount field
  /// already establishes -- then kept current by the field's own
  /// [MoneyTextField.onParsed] as the user edits it.
  Money? _creditLimit;

  bool get _isCreditCard => widget.account.subtypeValue == FinancialAccountSubtype.creditCard;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _type = widget.account.type;
    final CreditFacilityDetailsRow? facility = widget.initialCreditFacility;
    if (facility != null) {
      _creditLimit = facility.creditLimitAs(widget.account.currencyCode);
    }
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
    // Checkpoint O: a credit-card account without a resolved credit
    // limit yet (the brief `initialCreditFacility == null` gap --
    // see this widget's own doc) has no valid value to persist. This
    // should be unreachable in practice (the gap is at most one frame,
    // long before a user could tap Save), but Save simply does nothing
    // rather than writing a fabricated limit or crashing on a null
    // check.
    if (_isCreditCard && _creditLimit == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(accountRepositoryProvider).updateAccount(
            id: widget.account.id,
            name: _nameController.text.trim(),
            type: _type,
          );
      // Checkpoint O: editing the credit limit is a SEPARATE write,
      // through `CreditFacilityRepository.updateCreditLimit` -- never
      // folded into `updateAccount` (which has no `creditLimit`
      // parameter and never will; the limit lives on
      // `CreditFacilityDetails`, not `Accounts` -- see that
      // repository's own doc). Deliberately two awaited calls, not one
      // wrapped transaction: `updateAccount`'s own existing
      // `deletedAt.isNull()` guard already makes the first call a
      // no-op-or-throw for a closed account (unreachable here anyway --
      // the Edit icon is never shown for one), and neither write can
      // partially corrupt the other's target row.
      if (_isCreditCard) {
        await ref.read(creditFacilityRepositoryProvider).updateCreditLimit(
              accountId: widget.account.id,
              creditLimit: _creditLimit!,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Checkpoint G Android regression repair (docs/20 §13.2): a
    // `creditCard`/`deposit` account has no dedicated edit screen yet
    // (§13.4 checkpoint F/H), so this generic screen is still what Edit
    // reaches for one today -- but its type control must not offer a
    // relabel that would misrepresent (without ever actually being able
    // to change) the composite record those two subtypes carry. See
    // `isAccountTypeEditable`'s own doc.
    final bool typeEditable = isAccountTypeEditable(widget.account.subtypeValue);
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
                  typeOptions: kEditableAccountTypeLabels,
                  typeEditable: typeEditable,
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
                // Checkpoint O: the one field this screen adds --
                // shown only for a credit-card account, and only once
                // its facility has actually resolved (see this state
                // class's own doc; `initialCreditFacility` may briefly
                // be `null` on a credit card's very first build, in
                // which case this widget is about to be torn down and
                // rebuilt anyway once the real value arrives).
                if (_isCreditCard && widget.initialCreditFacility != null) ...<Widget>[
                  const SizedBox(height: 16),
                  MoneyTextField(
                    key: const Key('editCreditLimitField'),
                    currencyCode: widget.account.currencyCode,
                    label: l10n.editCreditLimitFieldLabel,
                    initialValue: widget.initialCreditFacility!
                        .creditLimitAs(widget.account.currencyCode)
                        .toMajorUnitsString(),
                    onParsed: (Money? v) => setState(() => _creditLimit = v),
                  ),
                ],
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
