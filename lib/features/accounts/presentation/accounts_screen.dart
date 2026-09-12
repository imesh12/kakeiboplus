import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import 'account_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load accounts: $e')),
        data: (List<AccountRow> accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('No accounts yet. Tap + to add one.'));
          }
          return ListView(
            children: <Widget>[
              for (final AccountRow account in accounts)
                Consumer(
                  builder: (BuildContext context, WidgetRef ref, _) {
                    final AsyncValue<Money> balanceAsync =
                        ref.watch(accountBalanceProvider(account.id));
                    final String metadata = '${account.type} · ${account.currencyCode}';
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
                    // always renders in full -- see its doc comment. No
                    // `onTap` existed on this row before this change and
                    // none is added here; this screen's own `ListView`
                    // padding and row spacing are preserved via the same
                    // `Padding` `ListTile` would otherwise have applied
                    // internally.
                    return Padding(
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
                          final TextStyle? moneyStyle = Theme.of(context).textTheme.titleMedium;
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
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Widget descriptive = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
        Text(
          metadata,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
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
    return AlertDialog(
      title: const Text('Add account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: <DropdownMenuItem<String>>[
                for (final String type in _accountTypes)
                  DropdownMenuItem<String>(value: type, child: Text(type)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: const InputDecoration(labelText: 'Currency'),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
