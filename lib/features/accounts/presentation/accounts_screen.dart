import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import 'account_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Localized display label for a persisted account `type` value --
/// CP6.5. `type` is always one of `_AddAccountDialogState._accountTypes`
/// today (a closed, dialog-created set), so mapping it to a translated
/// label is safe and does not touch the stored value. Falls back to the
/// raw string for any value outside that set (defensive only; not
/// reachable through the current Add Account dialog).
String _accountTypeLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'cash':
      return l10n.accountTypeCash;
    case 'bank':
      return l10n.accountTypeBank;
    case 'card':
      return l10n.accountTypeCard;
    case 'wallet':
      return l10n.accountTypeWallet;
    default:
      return type;
  }
}

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountsSectionTitle)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text(l10n.couldNotLoadAccounts(e.toString()))),
        data: (List<AccountRow> accounts) {
          if (accounts.isEmpty) {
            // Visual System Convergence Checkpoint 7.3: restyled with the
            // shared `secondaryBody` role (muted body text), matching
            // Activity's true empty state -- same message, no action
            // (the FAB below remains the only entry point, as before).
            return Center(
              child: Text(
                l10n.noAccountsYetTapToAddMessage,
                style: context.appTypography.secondaryBody,
              ),
            );
          }
          // Visual System Convergence Checkpoint 7.3: matches Activity's
          // own `ListView.builder`'s `symmetric(vertical: 8)` padding --
          // purely vertical, so it doesn't affect the horizontal inset
          // analysis above. Combined with each row's own new vertical
          // `AppCard` margin (4 top/bottom), the first/last card now gets
          // the same breathing room from the screen edge Activity's rows
          // already have.
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              for (final AccountRow account in accounts)
                Consumer(
                  builder: (BuildContext context, WidgetRef ref, _) {
                    final AppLocalizations rowL10n = AppLocalizations.of(context);
                    final AsyncValue<Money> balanceAsync =
                        ref.watch(accountBalanceProvider(account.id));
                    final String metadata =
                        '${_accountTypeLabel(rowL10n, account.type)} · ${account.currencyCode}';
                    // CP5.2b: was a bare `ListTile(title:, subtitle:,
                    // trailing:)`. Same risk as the Home account tile
                    // `ListTile` fixed in CP5.2a: `trailing` is sized
                    // independently of `title`/`subtitle`, so a long
                    // account name or metadata string could leave the
                    // balance silently clipped (`Text`'s default
                    // `TextOverflow.clip`) at narrow widths or large text
                    // scales, with no thrown error and no visible sign a
                    // digit went missing. `_AccountsRow` replaces it with
                    // a measurement-based row that guarantees the balance
                    // always renders in full -- see its doc comment.
                    //
                    // Visual System Convergence Checkpoint 7.3: the bare
                    // `Padding` this row used is now `AppCard(bordered:
                    // true, ...)` -- a flat white, thin-bordered card
                    // matching Home/Activity's converged treatment,
                    // still with no `onTap` (this row has never
                    // navigated anywhere; tapping it does nothing before
                    // or after this checkpoint). `AppCard`'s own
                    // `padding` carries exactly the same
                    // `symmetric(horizontal: 16, vertical: 12)` this row
                    // always used, so the width fed to `_AccountsRow`'s
                    // internal `LayoutBuilder` from THAT padding alone is
                    // unchanged. The new `margin` (16 horizontal, 4
                    // vertical -- the same values Activity's own
                    // per-row outer `Padding` already uses) adds a
                    // second, symmetric 16px layer on each side, taking
                    // the TOTAL horizontal inset from 32 to 64 -- matching
                    // Home/Activity's own two-layer convention exactly.
                    // This was checked against every boundary-precision
                    // test in `accounts_screen_test.dart`: every test
                    // that asserts a specific horizontal/stacked outcome
                    // does so either at the default (800px+) test-surface
                    // width, where an extra 32px is immaterial, or at a
                    // narrow width specifically chosen to force the
                    // stacked branch -- and reducing the available width
                    // further only reinforces that same stacked outcome,
                    // it cannot flip a test the other way. The remaining
                    // narrow-width tests (VND/KWD large-amount cases)
                    // deliberately don't assert which branch renders.
                    return AppCard(
                      bordered: true,
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: balanceAsync.when(
                        loading: () => _AccountsRow(
                          accountId: account.id,
                          name: account.name,
                          metadata: metadata,
                          money: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (Object e, StackTrace st) => _AccountsRow(
                          accountId: account.id,
                          name: account.name,
                          metadata: metadata,
                          money: const Icon(Icons.error_outline),
                        ),
                        data: (Money balance) {
                          final String formatted = _formatter.format(balance);
                          // Visual System Convergence Checkpoint 7.3:
                          // bumped from `textTheme.titleMedium` to the
                          // shared `AppTypography.mediumMoney` role
                          // (`titleLarge` + `w700`) for stronger visual
                          // emphasis on the authoritative balance -- a
                          // `TextStyle`-only change; the balance still
                          // renders as a plain `Text` (not `AppMoneyText`)
                          // so the style used to MEASURE it and the style
                          // it actually RENDERS with can never diverge,
                          // exactly like Home's own `_AdaptiveAccountRow`.
                          final TextStyle? moneyStyle = context.appTypography.mediumMoney;
                          return _AccountsRow(
                            accountId: account.id,
                            name: account.name,
                            metadata: metadata,
                            money: Text(formatted, style: moneyStyle),
                            moneyMeasureText: formatted,
                            moneyStyle: moneyStyle,
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddAccountDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => const _AddAccountDialog(),
    );
  }
}

/// Arranges an Accounts-screen row's descriptive content (name + "type ·
/// currency" metadata) against its authoritative balance -- International
/// / Localization Foundation Checkpoint 5.2b. Adapted from the same
/// measurement-based approach `_AdaptiveAccountRow` uses for the Home
/// account tile (CP5.2a): this row has no `Card` and a single combined
/// metadata line rather than two, matching this screen's own existing
/// visual hierarchy, but the underlying guarantee is identical.
///
/// This measures the balance's own natural (single-line) width at the
/// current text style and text scale ([MediaQuery.textScalerOf]) against
/// the row's actual available width ([LayoutBuilder]). The descriptive
/// column (name + metadata) is always allowed to ellipsize down to almost
/// nothing, so the only real question is whether the balance ALONE fits
/// the row: when it does, this renders name/metadata and the balance side
/// by side -- unchanged in spirit from the previous `ListTile`
/// arrangement, keyed `'accountsRowHorizontal_<accountId>'`. When the
/// balance alone would not fit even with the descriptive column squeezed
/// to nothing, the balance instead moves onto its own line below the
/// descriptive content, given the row's full width rather than whatever a
/// row would have left over -- keyed `'accountsRowStacked_<accountId>'`.
///
/// The balance is never wrapped in `FittedBox`, never ellipsized, and
/// never has `maxLines` capped in either arrangement -- every digit
/// `MoneyFormatter` produced always renders. In the rare case where even
/// the full stacked width isn't enough for one line, it simply wraps onto
/// a second line rather than losing a digit. Only the account name and
/// metadata may ellipsize (each capped to one line) -- they are never the
/// authoritative figure. While the balance is still loading or errored,
/// [moneyMeasureText] is left null and this always renders horizontally --
/// a small spinner or icon never needs to stack.
///
/// Deliberately does not branch on currency code -- the decision depends
/// only on the balance string's own measured width, so it applies
/// identically regardless of what produced it.
class _AccountsRow extends StatelessWidget {
  const _AccountsRow({
    required this.accountId,
    required this.name,
    required this.metadata,
    required this.money,
    this.moneyMeasureText,
    this.moneyStyle,
  });

  /// Distinguishes this row's layout-mode keys from every other account
  /// row on the same screen -- tests assert on
  /// `Key('accountsRowHorizontal_<accountId>')`/
  /// `Key('accountsRowStacked_<accountId>')` to confirm which arrangement
  /// actually rendered for a specific seeded account.
  final String accountId;
  final String name;
  final String metadata;

  /// The trailing content: the formatted balance `Text` once loaded, or a
  /// small fixed-size loading spinner / error icon otherwise.
  final Widget money;

  /// The exact string [money] renders when it's the formatted balance,
  /// used only to measure whether it fits the row. Null while
  /// loading/erroring.
  final String? moneyMeasureText;
  final TextStyle? moneyStyle;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    // Visual System Convergence Checkpoint 7.3: the account name is now
    // semibold (matching Activity's own transaction-title weight) for a
    // more "prominent name" per this checkpoint's design direction, and
    // the metadata line is `AppTypography.caption` -- exactly the
    // `bodySmall` + `onSurfaceVariant` shape it already had, just named
    // via the shared role instead of hand-rolled.
    final Widget descriptive = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          metadata,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.appTypography.caption,
        ),
      ],
    );

    final String? measureText = moneyMeasureText;
    if (measureText == null) {
      // Loading/error: nothing to stack -- the trailing widget is small
      // and fixed-size.
      return MergeSemantics(
        child: Row(
          key: Key('accountsRowHorizontal_$accountId'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: descriptive),
            const SizedBox(width: _gap),
            money,
          ],
        ),
      );
    }

    return MergeSemantics(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final scaler = MediaQuery.textScalerOf(context);
          final direction = Directionality.of(context);
          final double moneyWidth = (TextPainter(
            text: TextSpan(text: measureText, style: moneyStyle),
            textDirection: direction,
            textScaler: scaler,
          )..layout())
              .width;

          final bool fitsHorizontal = moneyWidth + _gap <= constraints.maxWidth;

          if (fitsHorizontal) {
            return Row(
              key: Key('accountsRowHorizontal_$accountId'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: descriptive),
                const SizedBox(width: _gap),
                money,
              ],
            );
          }

          return Column(
            key: Key('accountsRowStacked_$accountId'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              descriptive,
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: money),
            ],
          );
        },
      ),
    );
  }
}

class _AddAccountDialog extends ConsumerStatefulWidget {
  const _AddAccountDialog();

  @override
  ConsumerState<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<_AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _type = 'cash';
  String _currencyCode = CurrencyRegistry.seed.first.code;
  bool _isSaving = false;

  static const List<String> _accountTypes = <String>['cash', 'bank', 'card', 'wallet'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;
      await ref.read(accountRepositoryProvider).createAccount(
            profileId: profile.id,
            name: _nameController.text.trim(),
            type: _type,
            currencyCode: _currencyCode,
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
      title: Text(l10n.addAccountDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.accountNameLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.enterAccountNameMessage : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.accountTypeLabel),
              items: <DropdownMenuItem<String>>[
                for (final String type in _accountTypes)
                  DropdownMenuItem<String>(value: type, child: Text(_accountTypeLabel(l10n, type))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: InputDecoration(labelText: l10n.currencySection),
              items: <DropdownMenuItem<String>>[
                for (final currency in CurrencyRegistry.seed)
                  DropdownMenuItem<String>(value: currency.code, child: Text(currency.code)),
              ],
              onChanged: (v) => setState(() => _currencyCode = v ?? _currencyCode),
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
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.addAccountButton),
        ),
      ],
    );
  }
}
