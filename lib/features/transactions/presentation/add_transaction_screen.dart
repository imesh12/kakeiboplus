import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/database/repositories/transaction_not_found_exception.dart';
import '../../../core/money/currency_mismatch_exception.dart';
import '../../../core/money/money.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import 'transaction_icon_badge.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Add Expense / Add Income / Transfer, OR edit an existing one of
/// those — one screen either way, per `docs/02_SCREEN_CATALOG.md` items
/// 9-11 and `docs/14_DECISION_LOG.md` ADR-025 (Beta 1 Transaction UX).
///
/// Beta 1 Transaction UX Phase B, Checkpoint 5 modernizes this form's
/// visual presentation only -- a fixed-type header (reusing
/// [TransactionIconBadge]), tighter field grouping, a From -> To
/// affordance for transfers, and a clearer Save CTA. Every field,
/// provider/repository call, and validation path is unchanged from
/// before this checkpoint; see `_submit`, `_pickDate`, and the two
/// dropdown classes below, none of which changed behavior.
///
/// Add mode is driven by [initialType] ('expense' | 'income' |
/// 'transfer'); edit mode is driven by [existingTransaction] instead,
/// whose own `type` becomes this screen's fixed `_type` -- **editing
/// never changes a transaction's type** (ADR-025), so there is no code
/// path here that lets edit mode pick a different one. `type` is fixed
/// for the lifetime of one screen instance either way; switching type in
/// add mode re-opens the Add sheet rather than mutating the form in
/// place, which keeps the form state simple and matches how the sheet in
/// `add_transaction_sheet.dart` presents the three as distinct choices.
/// The Checkpoint 5 header renders this fixed type as plain,
/// non-interactive content (no dropdown, no tap target) in both add and
/// edit mode, so it reads as fixed/non-editable without needing a
/// separate "locked" indicator.
///
/// Visual System Convergence Checkpoint 7.7 (scoped as "Edit Transaction"
/// visual convergence -- see `EditTransactionScreen`'s own doc comment;
/// this is the one screen that actually renders the edit form) brings this
/// form's presentation onto the same shared primitives (`AppCard`,
/// `AppTypography`) every other converged screen already uses, replacing
/// the two hand-written `Card(elevation: 0, shape: RoundedRectangleBorder(
/// ...))` sections and the amount field's ad hoc tinted `Container` with
/// the shared equivalents. Because add and edit share this one widget by
/// design (see above), add mode picks up the exact same visual refresh as
/// a byproduct -- every field, provider/repository call, and validation
/// path is unchanged either way.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.initialType, this.existingTransaction});

  final String? initialType;

  /// Non-null means edit mode: this screen prefills every field from
  /// the existing row and calls the repository's `update*` methods
  /// instead of `record*` on save. See [EditTransactionScreen], which
  /// resolves a transaction id to this before ever constructing this
  /// widget.
  final Transaction? existingTransaction;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _type = widget.existingTransaction != null
      ? widget.existingTransaction!.type
      : (<String>['expense', 'income', 'transfer'].contains(widget.initialType)
          ? widget.initialType!
          : 'expense');

  String? _accountId;
  String? _destinationAccountId;
  String? _categoryId;
  String? _note;
  Money? _amount;
  DateTime _occurredAt = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isTransfer => _type == 'transfer';
  bool get _isEditing => widget.existingTransaction != null;

  /// The plain type word shown in the Checkpoint 5 header -- distinct
  /// from [_titleFor], which produces the AppBar's "Add expense"/"Edit
  /// income"/etc. title text. CP6.2: reuses the same
  /// `transactionType*` ARB keys CP6.1 already introduced for the Add
  /// sheet (`add_transaction_sheet.dart`) rather than duplicating them --
  /// both surfaces show the same three words.
  String _typeLabel(AppLocalizations l10n) => switch (_type) {
        'income' => l10n.transactionTypeIncome,
        'transfer' => l10n.transactionTypeTransfer,
        _ => l10n.transactionTypeExpense,
      };

  // Plain-decimal seed text for `MoneyTextField` in edit mode --
  // `Money.toMajorUnitsString()`, NOT `MoneyFormatter.format()`, because
  // the latter includes a currency symbol/grouping and won't round-trip
  // through `MoneyParser.parse()`.
  String? _initialAmountText;

  @override
  void initState() {
    super.initState();
    final Transaction? existing = widget.existingTransaction;
    if (existing != null) {
      _accountId = existing.accountId;
      _destinationAccountId = existing.destinationAccountId;
      _categoryId = existing.categoryId;
      _note = existing.note;
      _amount = Money.fromMinorUnits(existing.amountMinorUnits, existing.currencyCode);
      _initialAmountText = _amount!.toMajorUnitsString();
      // Stored in UTC; the date picker and every field on this screen
      // work in local time, converted back to UTC only at submit —
      // same convention the add flow already uses for `_occurredAt`.
      _occurredAt = existing.occurredAt.toLocal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // CP6.2 (Localization Phase 1): resolved once per build and reused
    // by every literal string below (header, dropdown labels, empty/
    // error states, Save) -- `_DestinationAccountDropdown` and
    // `_CategoryDropdown` are separate widgets below and resolve their
    // own copy from their own `context` instead.
    final AppLocalizations l10n = AppLocalizations.of(context);
    // ColorScheme-driven per type -- matches the convention Activity and
    // Transaction Detail (Checkpoints 2/4) already established, so the
    // same transaction type reads consistently everywhere in the app.
    final Color typeColor = switch (_type) {
      'income' => colors.primary,
      'transfer' => colors.onSurfaceVariant,
      _ => colors.error,
    };
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(l10n, _type))),
      body: SafeArea(
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace st) =>
              Center(child: Text(l10n.couldNotLoadAccounts(e.toString()))),
          data: (List<AccountRow> accounts) {
            if (accounts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.addAccountFirstMessage),
                ),
              );
            }
            _accountId ??= accounts.first.id;
            final AccountRow? selectedAccount = _findAccount(accounts, _accountId);

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  // A. Transaction header -- the fixed type is obvious
                  // (icon + color + label), and, since nothing here is
                  // tappable, it reads as fixed/non-editable in edit
                  // mode without a separate "locked" affordance.
                  // TransactionIconBadge is reused unmodified; the
                  // header always passes a null category icon since it
                  // represents the transaction TYPE, not whichever
                  // category happens to be selected at any given moment.
                  Center(
                    child: Column(
                      children: <Widget>[
                        Semantics(
                          label: _typeLabel(l10n),
                          child: TransactionIconBadge(type: _type, color: typeColor),
                        ),
                        const SizedBox(height: 8),
                        // Checkpoint 7.7: `AppTypography.cardTitle` is the
                        // same `titleMedium` + `FontWeight.w600` this
                        // already rendered with -- a pure rename onto the
                        // shared role, with the type color still applied
                        // on top exactly as before.
                        Text(
                          _typeLabel(l10n),
                          style: context.appTypography.cardTitle?.copyWith(color: typeColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // C. Account/category grouping -- the exact same
                  // account DropdownButtonFormField (and the unmodified
                  // `_DestinationAccountDropdown`/`_CategoryDropdown`
                  // widgets below), same labels/validators/wiring/order,
                  // just visually grouped in one bordered section.
                  // D. Transfer From -> To: a small decorative arrow
                  // between the two dropdowns communicates direction --
                  // no new selector, no duplicated account picker, no
                  // logic of its own.
                  // Checkpoint 7.7: the same shared `AppCard(bordered: true)`
                  // treatment every other converged screen uses in place of
                  // a hand-written `Card(elevation: 0, shape:
                  // RoundedRectangleBorder(..., side: BorderSide(color:
                  // colors.outlineVariant)))` -- pixel-equivalent (same flat
                  // white surface, subtle border, 16-radius corners); every
                  // dropdown/field inside is unchanged.
                  AppCard(
                    bordered: true,
                    child: Column(
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          initialValue: _accountId,
                          // CP6.2 follow-up: `isExpanded: true` -- without it,
                          // `DropdownButton`'s own inner Row sizes itself to the
                          // UNCLAMPED intrinsic width of the selected item's Text,
                          // so the `overflow: TextOverflow.ellipsis` already set on
                          // that Text below never gets a chance to engage (there is
                          // no bounded width for it to ellipsize against) -- a
                          // documented `DropdownButton` gotcha, not something
                          // specific to any one language. `isExpanded: true` makes
                          // the button fill the available width instead, which is
                          // what actually lets the ellipsis do its job at a narrow
                          // viewport/large text scale, for a long account name in
                          // ANY locale.
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _isTransfer ? l10n.fromAccountLabel : l10n.accountLabel,
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
                          onChanged: (String? id) => setState(() {
                            _accountId = id;
                            if (_destinationAccountId == _accountId) _destinationAccountId = null;
                          }),
                        ),
                        if (_isTransfer) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Icon(
                              Icons.arrow_downward,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          _DestinationAccountDropdown(
                            accounts: accounts,
                            sourceAccountId: _accountId,
                            value: _destinationAccountId,
                            onChanged: (String? id) => setState(() => _destinationAccountId = id),
                          ),
                        ],
                        if (!_isTransfer) ...<Widget>[
                          const SizedBox(height: 12),
                          _CategoryDropdown(
                            type: _type,
                            value: _categoryId,
                            onChanged: (String? id) => setState(() => _categoryId = id),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // B. Amount emphasis -- the exact same MoneyTextField
                  // widget, callbacks, and position relative to the
                  // other fields. Checkpoint 7.7 replaces the previous ad
                  // hoc alpha-tinted `Container` backdrop with the same
                  // bordered `AppCard` treatment the rest of this form (and
                  // the rest of the converged app) uses, at the larger
                  // `radii.large` corner radius `AppCard`'s own doc comment
                  // documents for a hero-style emphasis card -- still a
                  // flat, restrained, white/bordered surface, not a change
                  // to the field itself or its position relative to the
                  // other sections.
                  if (selectedAccount != null)
                    AppCard(
                      bordered: true,
                      radius: context.appTokens.radii.large,
                      padding: const EdgeInsets.all(8),
                      child: MoneyTextField(
                        currencyCode: selectedAccount.currencyCode,
                        label: l10n.amountLabel,
                        initialValue: _initialAmountText,
                        onParsed: (Money? amount) => setState(() => _amount = amount),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // E. Note/date -- the exact same TextFormField/ListTile
                  // widgets and wiring, grouped into one bordered
                  // section for hierarchy. The calendar icon and
                  // `_pickDate` wiring are unchanged. Checkpoint 7.7: same
                  // shared `AppCard(bordered: true)` swap as the
                  // account/category section above, with the exact same
                  // `fromLTRB(16, 12, 16, 4)` padding preserved (the
                  // `ListTile`/borderless `TextFormField` already carry
                  // their own internal spacing).
                  AppCard(
                    bordered: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          initialValue: _note,
                          decoration: InputDecoration(
                            labelText: l10n.noteOptionalLabel,
                            border: InputBorder.none,
                          ),
                          onChanged: (String value) => _note = value,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.dateLabel),
                          subtitle: Text(
                            '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-'
                            '${_occurredAt.day.toString().padLeft(2, '0')}',
                          ),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: _pickDate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...<Widget>[
                    Text(
                      _errorMessage!,
                      style: context.appTypography.body?.copyWith(color: colors.error),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // F. Save CTA -- same FilledButton/"Save"/loading-
                  // spinner swap and the same `_submit` call.
                  // `minimumSize` gives it a strong floor height without
                  // a hard cap, so it still grows correctly at large
                  // text scales instead of clipping.
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _isSaving ? null : () => _submit(accounts),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        ),
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
    if (picked == null) return;
    // Decision 3 (ADR-025): changing a transaction's date must preserve
    // its existing local time-of-day rather than collapsing it to
    // midnight -- combine the newly-picked calendar date with the
    // *existing* hour/minute/second, then convert to UTC at submit as
    // before. This is the same code path for add and edit; in add mode
    // `_occurredAt` starts as `DateTime.now()`, so "existing" time-of-day
    // is simply whatever time was already showing.
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
        _occurredAt.second,
      );
    });
  }

  Future<void> _submit(List<AccountRow> accounts) async {
    // CP6.2: resolved once, before any `await` below -- a plain value
    // read from `context`, not a `BuildContext` itself, so it's safe to
    // keep using across the async gaps that follow (unlike, say,
    // `Navigator.of(context)`, which this method re-derives from
    // `context` only after checking `mounted`).
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_amount == null) {
      setState(() => _errorMessage = l10n.enterValidAmount);
      return;
    }
    if (_isTransfer && _destinationAccountId == null) {
      setState(() => _errorMessage = l10n.chooseDestinationAccount);
      return;
    }

    // Guard against a category deleted out from under an open edit
    // screen: re-check right before submit that it's still valid for
    // this transaction type, rather than trusting whatever was loaded
    // when the screen first opened. A one-shot `.read`, not `.watch` --
    // this is an event handler, not part of the widget's reactive build.
    if (!_isTransfer && _categoryId != null) {
      final List<CategoryRow>? categories =
          ref.read(categoriesForTypeProvider(_type)).valueOrNull;
      if (categories != null && !categories.any((CategoryRow c) => c.id == _categoryId)) {
        _categoryId = null;
      }
    }

    setState(() => _isSaving = true);
    try {
      final TransactionRepository repo = ref.read(transactionRepositoryProvider);
      final DateTime occurredAtUtc = _occurredAt.toUtc();
      final Transaction? existing = widget.existingTransaction;

      if (existing == null) {
        final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
        if (profile == null) return;
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
      } else {
        // Editing: `_type` is fixed to `existing.type` for the lifetime
        // of this screen (see the `_type` field doc comment), so this
        // switch can never change a transaction's type -- ADR-025.
        switch (_type) {
          case 'expense':
            await repo.updateExpense(
              id: existing.id,
              accountId: _accountId!,
              amount: _amount!,
              categoryId: _categoryId,
              note: _note,
              occurredAtUtc: occurredAtUtc,
            );
          case 'income':
            await repo.updateIncome(
              id: existing.id,
              accountId: _accountId!,
              amount: _amount!,
              categoryId: _categoryId,
              note: _note,
              occurredAtUtc: occurredAtUtc,
            );
          case 'transfer':
            await repo.updateTransfer(
              id: existing.id,
              sourceAccountId: _accountId!,
              destinationAccountId: _destinationAccountId!,
              amount: _amount!,
              note: _note,
              occurredAtUtc: occurredAtUtc,
            );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on CurrencyMismatchException catch (e) {
      // Belt-and-braces: for transfers, the destination dropdown already
      // only offers same-currency accounts (ADR-019); for an edited
      // expense/income, `MoneyTextField` re-validates the typed amount
      // under a newly-selected account's currency (see
      // money_text_field.dart's `didUpdateWidget`). Either way the
      // repository enforces this independently -- see
      // transaction_repository.dart -- so surface its rejection cleanly
      // rather than letting it crash.
      setState(() {
        _errorMessage = l10n.currencyMismatchError(e.currencyCodeA, e.currencyCodeB);
      });
    } on TransactionNotFoundException {
      setState(() {
        _errorMessage = l10n.transactionNoLongerAvailable;
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.couldNotSaveTransaction(e.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _titleFor(AppLocalizations l10n, String type) {
    if (_isEditing) {
      return switch (type) {
        'income' => l10n.editIncomeTitle,
        'transfer' => l10n.editTransferTitle,
        _ => l10n.editExpenseTitle,
      };
    }
    return switch (type) {
      'income' => l10n.addIncomeTitle,
      // Add-mode transfer reuses the exact same word/translation as the
      // header label and the Add sheet (CP6.1) -- "Transfer"/"振替" is
      // one concept, not a separate title string.
      'transfer' => l10n.transactionTypeTransfer,
      _ => l10n.addExpenseTitle,
    };
  }
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
    // CP6.2: this widget renders its own copy independently of
    // `AddTransactionScreen.build`'s -- it's a separate `StatelessWidget`
    // with its own `context`, same pattern `_CategoryDropdown` below uses.
    final AppLocalizations l10n = AppLocalizations.of(context);
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
        l10n.noEligibleTransferDestination(source.currencyCode),
        style: context.appTypography.body?.copyWith(color: Theme.of(context).colorScheme.error),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: eligible.any((a) => a.id == value) ? value : null,
      // See the account dropdown's own comment above (same file) --
      // without this, a long account name can overflow this button's row
      // at a narrow viewport/large text scale in any locale.
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.toAccountLabel),
      items: <DropdownMenuItem<String>>[
        for (final AccountRow account in eligible)
          DropdownMenuItem<String>(
            value: account.id,
            child: Text(account.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      validator: (String? v) => v == null ? l10n.chooseDestinationAccount : null,
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
    // CP6.2: this widget renders its own copy independently of
    // `AddTransactionScreen.build`'s -- it's a separate `ConsumerWidget`
    // with its own `context`.
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider(type));
    return categoriesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (Object e, StackTrace st) => Text(l10n.couldNotLoadCategories(e.toString())),
      data: (List<CategoryRow> categories) {
        return DropdownButtonFormField<String>(
          initialValue: categories.any((c) => c.id == value) ? value : null,
          // See the account dropdown's own comment above (same file) --
          // without this, a long category name can overflow this button's
          // row at a narrow viewport/large text scale in any locale.
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.categoryOptionalLabel),
          items: <DropdownMenuItem<String>>[
            for (final CategoryRow category in categories)
              DropdownMenuItem<String>(
                value: category.id,
                child: Text(category.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
