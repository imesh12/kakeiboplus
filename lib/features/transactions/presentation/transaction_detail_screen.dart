import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/transaction_linked_to_cheque_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import '../../services/domain/service_identity_catalog.dart';
import 'transaction_icon_badge.dart';
import 'transaction_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Read-only detail for one transaction, with edit and delete entry
/// points — Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025).
/// Checkpoint 4 (Phase B) modernizes this screen's visual presentation
/// only -- a header block (icon badge + type + category + the amount as
/// the primary visual element) above a restyled metadata section. Every
/// read path, the edit/delete actions, and the unavailable state are
/// unchanged from Phase A/Checkpoint 3.
///
/// Mirrors `GoalDetailScreen`'s "no longer available" + confirm-delete
/// pattern (ADR-022) for the same reason: a soft-deleted or nonexistent
/// [transactionId] must resolve to an explicit unavailable state below
/// the UI layer, not stale data — `transactionByIdProvider` already
/// guarantees this; this screen just renders what it's given.
///
/// Visual System Convergence Checkpoint 7.7 brings this screen's
/// presentation onto the same shared primitives (`AppCard`,
/// `AppTypography`) every other converged screen (Goal Detail, Recurring,
/// Categories, Settings) already uses, replacing the hand-written
/// `Card(elevation: 0, shape: RoundedRectangleBorder(...))` + ad hoc
/// `TextTheme` styles Checkpoint 4 introduced with the shared
/// equivalents. Every read path, the header's information hierarchy, the
/// edit/delete actions, and the unavailable state are unchanged.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Transaction?> txAsync = ref.watch(transactionByIdProvider(transactionId));
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactionDetailScreenTitle),
        actions: <Widget>[
          if (txAsync.valueOrNull != null) ...<Widget>[
            IconButton(
              key: const Key('editTransaction'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTooltip,
              onPressed: () => context.push(AppRoutes.editTransaction(transactionId)),
            ),
            IconButton(
              key: const Key('deleteTransaction'),
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteTooltip,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text(l10n.couldNotLoadTransactionDetail('$e'))),
        data: (Transaction? tx) {
          if (tx == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.transactionNoLongerAvailable,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _TransactionDetailBody(tx: tx);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.deleteTransactionConfirmTitle),
        content: Text(l10n.deleteTransactionConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmDeleteTransaction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(transactionRepositoryProvider).softDelete(transactionId);
      if (context.mounted) context.pop();
    } on TransactionLinkedToChequeException {
      // Checkpoint N: this transaction is a cleared cheque's own
      // posting -- see `TransactionRepository._requireNotChequeLinked`'s
      // own doc. Same "catch the domain exception, show it, leave the
      // transaction exactly as it was" pattern
      // `ChequeDetailScreen._confirmDelete` already uses for
      // `ChequeLifecycleException`.
      if (context.mounted) {
        _showError(context, l10n.transactionLinkedToChequeError);
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TransactionDetailBody extends ConsumerWidget {
  const _TransactionDetailBody({required this.tx});
  final Transaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Account Lifecycle Checkpoint: sourced from `allAccountsProvider`
    // (not `accountsProvider`) so a transaction referencing a since-
    // closed account still resolves that account's real name here,
    // instead of falling back to an "unknown account" label.
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(allAccountsProvider);

    final bool isTransfer = tx.type == 'transfer';

    // A transfer never carries a category (ADR-025 Correction 2), so
    // there is nothing for it to resolve here -- watching
    // `categoriesForTypeProvider('transfer')` for a transfer would just
    // be an unused subscription (confirmed unnecessary by the
    // Checkpoint 4 audit). `ref.watch` calls aren't order-sensitive the
    // way React hooks are, so branching on `isTransfer` (stable for the
    // lifetime of this widget, since it's derived from `tx.type`, which
    // never changes on an existing row) is safe here.
    final AsyncValue<List<CategoryRow>>? categoriesAsync =
        isTransfer ? null : ref.watch(categoriesForTypeProvider(tx.type));

    final Map<String, String> accountNames = <String, String>{
      for (final AccountRow a in accountsAsync.valueOrNull ?? const <AccountRow>[]) a.id: a.name,
    };
    // Account Lifecycle UX polish: which of those same (already-
    // resolved) accounts are CURRENTLY closed -- resolved fresh at
    // presentation time from `allAccountsProvider`'s own rows, never
    // written into this transaction. Reactivating the account simply
    // stops setting this on the next rebuild; nothing about the
    // transaction itself ever changes.
    final Set<String> closedAccountIds = <String>{
      for (final AccountRow a in accountsAsync.valueOrNull ?? const <AccountRow>[])
        if (a.deletedAt != null) a.id,
    };
    // Keyed by id -> the full row (not just the name), so the header can
    // also read `CategoryRow.icon` for `TransactionIconBadge` -- still
    // derived entirely from the same `categoriesForTypeProvider` watch
    // this screen already had; no new provider, no new query.
    final Map<String, CategoryRow> categoriesById = <String, CategoryRow>{
      for (final CategoryRow c in categoriesAsync?.valueOrNull ?? const <CategoryRow>[]) c.id: c,
    };
    final CategoryRow? category =
        (isTransfer || tx.categoryId == null) ? null : categoriesById[tx.categoryId];

    final Money amount = Money.fromMinorUnits(tx.amountMinorUnits, tx.currencyCode);
    // Sign/formatting convention is byte-for-byte unchanged from before
    // Checkpoint 4 -- '+' income, '' transfer, '-' expense; Money is
    // still built only from `tx.amountMinorUnits`/`tx.currencyCode`, no
    // conversion, no relabeling.
    final String amountPrefix = switch (tx.type) {
      'income' => '+',
      'transfer' => '',
      _ => '-',
    };
    // ColorScheme-driven for every type, including income -- Checkpoint
    // 4 replaces the previous hardcoded `Colors.green` with
    // `colors.primary`, matching the convention Activity already
    // established.
    //
    // Checkpoint 8.2 (Whole-App Theme Compatibility): income now reads
    // through `AppTokens.colors.positive` instead of `colorScheme.primary`
    // directly -- see `add_transaction_screen.dart`'s matching comment for
    // why (the Forest theme's income/decorative-green safety mechanism).
    final Color amountColor = switch (tx.type) {
      'income' => context.appTokens.colors.positive,
      'transfer' => colors.onSurfaceVariant,
      _ => colors.error,
    };
    final String typeLabel = switch (tx.type) {
      'income' => l10n.transactionTypeIncome,
      'transfer' => l10n.transactionTypeTransfer,
      _ => l10n.transactionTypeExpense,
    };
    // Preserves the exact existing fallback text: no categoryId at all
    // -> 'None'; a categoryId that doesn't resolve (deleted/unrecognized)
    // -> '—'; otherwise the resolved name.
    final String categoryDisplayValue =
        tx.categoryId == null ? l10n.noneOptionLabel : (category?.name ?? '—');

    // Checkpoint U2 (Service / Merchant Identity Integration): unlike
    // `category` above, `serviceIdentityDefinitionFor` never fails to
    // resolve a NON-null key -- an unrecognized/legacy key still lands
    // on the generic "other" family definition (see that function's own
    // doc comment) -- so there is no analogous "resolved but no name"
    // '—' case here; only "no key at all" -> None.
    final ServiceIdentityDefinition? serviceDefinition =
        isTransfer ? null : serviceIdentityDefinitionFor(tx.serviceIdentityKey);
    final String? serviceDisplayName =
        serviceDefinition != null ? serviceIdentityDisplayName(l10n, serviceDefinition) : null;
    final String serviceDisplayValue = tx.serviceIdentityKey == null || isTransfer
        ? l10n.noneOptionLabel
        : (serviceDisplayName ?? l10n.noneOptionLabel);

    final String formattedAmount = _formatter.format(amount);
    // Spoken sign, independent of the visual '+'/'-'/none prefix and of
    // amountColor -- "don't rely on color alone" extends to the amount
    // too, matching Activity's row convention.
    final String spokenAmount = switch (tx.type) {
      'income' => l10n.spokenPlusAmount(formattedAmount),
      'transfer' => formattedAmount,
      _ => l10n.spokenMinusAmount(formattedAmount),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _DetailHeader(
          type: tx.type,
          typeLabel: typeLabel,
          // Checkpoint U2: same service > category precedence as
          // Activity's row title -- only shown in the header when
          // there's an actual name to show (service OR category), never
          // both stacked; the metadata card below always shows both
          // fields explicitly regardless of which one (if any) appears
          // here.
          categoryName: isTransfer ? null : (serviceDisplayName ?? category?.name),
          categoryIconName: isTransfer ? null : category?.icon,
          serviceIdentityKey: isTransfer ? null : tx.serviceIdentityKey,
          amountColor: amountColor,
          amountPrefix: amountPrefix,
          formattedAmount: formattedAmount,
          spokenAmount: spokenAmount,
        ),
        const SizedBox(height: 24),
        // Visual System Convergence Checkpoint 7.7: the same shared
        // `AppCard(bordered: true)` treatment every other converged screen
        // (Goal Detail, Recurring, Categories, Settings) now uses in place
        // of a hand-written `Card(elevation: 0, shape: RoundedRectangleBorder(
        // ..., side: BorderSide(color: colors.outlineVariant)))` --
        // pixel-equivalent (same flat white surface, same subtle border, same
        // 16-radius corners), just the shared primitive instead of a local
        // copy of its exact recipe. Every row/value/divider inside is
        // unchanged.
        AppCard(
          bordered: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: <Widget>[
              if (isTransfer) ...<Widget>[
                _DetailRow(
                  label: l10n.transactionDetailFromLabel,
                  value: accountNames[tx.accountId] ?? '—',
                  showClosedBadge: closedAccountIds.contains(tx.accountId),
                  closedBadgeKey: const Key('transactionDetailFromAccountClosedBadge'),
                ),
                const Divider(height: 1),
                _DetailRow(
                  label: l10n.transactionDetailToLabel,
                  value: tx.destinationAccountId == null
                      ? '—'
                      : (accountNames[tx.destinationAccountId] ?? '—'),
                  showClosedBadge: tx.destinationAccountId != null &&
                      closedAccountIds.contains(tx.destinationAccountId!),
                  closedBadgeKey: const Key('transactionDetailToAccountClosedBadge'),
                ),
                const Divider(height: 1),
              ] else ...<Widget>[
                _DetailRow(
                  label: l10n.accountLabel,
                  value: accountNames[tx.accountId] ?? '—',
                  showClosedBadge: closedAccountIds.contains(tx.accountId),
                  closedBadgeKey: const Key('transactionDetailAccountClosedBadge'),
                ),
                const Divider(height: 1),
                _DetailRow(label: l10n.categoryFieldLabel, value: categoryDisplayValue),
                const Divider(height: 1),
                _DetailRow(label: l10n.serviceFieldLabel, value: serviceDisplayValue),
                const Divider(height: 1),
              ],
              _DetailRow(
                label: l10n.dateLabel,
                value: DateFormat.yMMMd().add_jm().format(tx.occurredAt.toLocal()),
              ),
              if (tx.note != null && tx.note!.isNotEmpty) ...<Widget>[
                const Divider(height: 1),
                _DetailRow(label: l10n.transactionDetailNoteLabel, value: tx.note!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The header block above the metadata card: [TransactionIconBadge] +
/// type label + (expense/income only) category name, with the amount as
/// the largest, most visually prominent element -- Checkpoint 4's
/// "make amount the primary visual element" requirement.
///
/// Purely presentational -- every value it renders is already resolved
/// by [_TransactionDetailBody]; this widget makes no provider/repository
/// calls of its own.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.type,
    required this.typeLabel,
    required this.categoryName,
    required this.categoryIconName,
    required this.amountColor,
    required this.amountPrefix,
    required this.formattedAmount,
    required this.spokenAmount,
    this.serviceIdentityKey,
  });

  /// `'expense'` | `'income'` | `'transfer'` -- `Transaction.type`,
  /// forwarded to [TransactionIconBadge] unchanged.
  final String type;
  final String typeLabel;

  /// Null for a transfer (a transfer is never categorized/service-
  /// identified) or an expense/income with neither resolved -- the
  /// header shows this line only when there's an actual name to show.
  ///
  /// Checkpoint U2: despite the name, the CALLER now resolves this to
  /// the service display name when a service identity is present,
  /// falling back to the category name otherwise -- the same service >
  /// category precedence used everywhere else in this checkpoint. This
  /// widget itself stays unaware of the distinction; it only renders
  /// whichever single name (if any) the caller decided wins.
  final String? categoryName;

  /// Null for a transfer, or for an expense/income with no category
  /// (or an unresolved one) -- forwarded to [TransactionIconBadge],
  /// which already falls back safely (via `categoryIconFor`, or to the
  /// plain type icon when this is null).
  final String? categoryIconName;

  /// Checkpoint U2: forwarded to [TransactionIconBadge], which gives it
  /// glyph precedence over [categoryIconName] when non-null -- null for
  /// a transfer or when no service was chosen.
  final String? serviceIdentityKey;
  final Color amountColor;
  final String amountPrefix;
  final String formattedAmount;
  final String spokenAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // The icon/color pairing is never the only signal for
        // transaction type -- `typeLabel` below is always visible text,
        // and this Semantics label makes the same information available
        // non-visually, matching Activity's established
        // "don't rely on color alone" pattern for its own row icons.
        Semantics(
          label: typeLabel,
          child: TransactionIconBadge(
            type: type,
            color: amountColor,
            categoryIconName: categoryIconName,
            serviceIdentityKey: serviceIdentityKey,
          ),
        ),
        const SizedBox(height: 12),
        // Checkpoint 7.7: the same `AppTypography.eyebrow` role every other
        // converged screen's small muted section/type label already uses
        // (Recurring's section headers, Goal Detail's "Contribution
        // history"), replacing this label's own hand-picked
        // `labelLarge`/`onSurfaceVariant`/`w600`/`letterSpacing: 0.5`
        // recipe -- one shade smaller and 0.3 more letter-spacing than
        // before, matching the rest of the app's own small-label rhythm
        // instead of a one-off variant of it.
        Text(typeLabel, style: context.appTypography.eyebrow),
        if (categoryName != null) ...<Widget>[
          const SizedBox(height: 2),
          // `AppTypography.cardTitle` is byte-for-byte the same
          // `titleMedium` + `FontWeight.w600` this already rendered with --
          // a pure rename onto the shared role, not a visual change.
          Text(categoryName!, style: context.appTypography.cardTitle),
        ],
        const SizedBox(height: 8),
        // `excludeSemantics: true` so the spoken sign ("plus"/"minus")
        // replaces the visual '+'/'-' glyph for a screen reader rather
        // than both being announced -- avoids the noisy/duplicate
        // semantics Checkpoint 4 explicitly asks to avoid.
        Semantics(
          label: spokenAmount,
          excludeSemantics: true,
          child: Text(
            '$amountPrefix$formattedAmount',
            // Key preserved exactly -- still a plain `Text` (not
            // `AppMoneyText`) specifically so the existing
            // `tester.widget<Text>(find.byKey(const
            // Key('transactionDetailAmount')))` color assertion (CP4's
            // "income must use colorScheme.primary, not a hardcoded
            // color" regression test) keeps working unmodified; only the
            // TEXT STYLE below moves onto the shared `largeMoney` role.
            key: const Key('transactionDetailAmount'),
            style: context.appTypography.largeMoney?.copyWith(color: amountColor),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showClosedBadge = false,
    this.closedBadgeKey,
  });
  final String label;
  final String value;

  /// Account Lifecycle UX polish: shows a small muted "Closed" badge
  /// beside [value] when it names an account that is CURRENTLY closed.
  /// `false` for every non-account row (date, category, note), and for
  /// an account row whose account is active or genuinely unresolvable
  /// (see the call sites in [_TransactionDetailBody] for how each is
  /// told apart). Purely presentational, resolved fresh per build --
  /// never changes [value] itself or anything about the transaction.
  final bool showClosedBadge;

  /// Distinguishes which account row's badge is which in tests (From vs.
  /// To on a transfer, or the single Account row otherwise) -- `null`
  /// when [showClosedBadge] is `false`.
  final Key? closedBadgeKey;

  @override
  Widget build(BuildContext context) {
    // Checkpoint 7.7: the same `context.appTypography.secondaryBody`/`body`
    // roles Goal Detail's own `_DetailRow` already uses for this exact
    // label/value pattern -- both are byte-for-byte the same
    // `bodyMedium`(+`onSurfaceVariant`)/`bodyMedium`+`w600` this already
    // rendered with, so this is a pure rename onto the shared roles.
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: context.appTypography.secondaryBody),
          ),
          const SizedBox(width: 12),
          Flexible(
            // Account Lifecycle UX polish: `Wrap` (not `Row`) so a long
            // account name plus the badge can drop to a second line
            // rather than overflow -- this row already right-aligns and
            // wraps its label column independently, so an occasional
            // extra line here for a long name is the same trade-off the
            // rest of this screen already makes, not a new one. When
            // [showClosedBadge] is `false` (the common case, and every
            // non-account row), this renders byte-for-byte the same
            // single `Text` as before this polish.
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: <Widget>[
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: context.appTypography.body?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (showClosedBadge)
                  AppStatusChip(
                    key: closedBadgeKey,
                    label: l10n.accountClosedLabel,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
