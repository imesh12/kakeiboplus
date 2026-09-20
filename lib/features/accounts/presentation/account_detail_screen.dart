import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/account_repository.dart' show AccountRowX;
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_finance_list_row.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../categories/presentation/category_providers.dart';
import '../../categories/domain/category_icon.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'account_providers.dart';
import 'account_type_presentation.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// V1 Accounts Detail + Edit Checkpoint: a polished, read-only detail
/// view for one account, reached by tapping its row on [AccountsScreen].
/// Reuses the existing account/transaction architecture unchanged --
/// this screen only ever reads through `accountByIdProvider`/
/// `accountBalanceProvider`/`accountRecentActivityProvider`, all
/// pre-existing repository methods (or thin wrappers over them); no
/// domain model, balance rule, or transfer semantic is new here.
///
/// If [accountId] no longer names an active account -- archived (once
/// that becomes possible), or never existed -- this resolves to an
/// explicit "no longer available" state rather than silently showing
/// stale data, the same convention `TransactionDetailScreen`/
/// `GoalDetailScreen` already use for their own ids.
///
/// Deliberately generic: cash/bank/card/wallet all render through this
/// one screen today. A future, richer Credit Card Detail screen can
/// specialize `type == 'card'` later by branching at the route level
/// (see `AppRoutes.accountDetailPath`'s doc comment) without another
/// navigation rewrite -- this screen does not need to anticipate what
/// that specialization looks like.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<AccountRow?> accountAsync = ref.watch(accountByIdProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        // The account's own name is user-entered content and is never
        // translated -- the fallback word shown only while loading (or
        // if the account can't be found) is the only localizable piece
        // here, matching `GoalDetailScreen`'s `goalFallbackTitle`
        // convention.
        title: Text(accountAsync.valueOrNull?.name ?? l10n.accountFallbackTitle),
        actions: <Widget>[
          if (accountAsync.valueOrNull != null)
            IconButton(
              key: const Key('editAccount'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTooltip,
              onPressed: () => context.push(AppRoutes.editAccount(accountId)),
            ),
        ],
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text(l10n.couldNotLoadAccountDetail('$e'))),
        data: (AccountRow? account) {
          if (account == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.accountNoLongerAvailableMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _AccountDetailBody(account: account);
        },
      ),
    );
  }
}

class _AccountDetailBody extends ConsumerWidget {
  const _AccountDetailBody({required this.account});
  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AsyncValue<Money> balanceAsync = ref.watch(accountBalanceProvider(account.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // [Account identity]: icon + name + "type · currency".
        Row(
          children: <Widget>[
            AppIconTile(
              icon: accountTypeIcon(account.type),
              color: colors.primary,
              size: AppIconTileSize.large,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    account.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTypography.cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${accountTypeDisplayLabel(l10n, account.type)} · ${account.currencyCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // [large current balance] -- the same derived-from-the-ledger
        // value `AccountsScreen`'s own row shows for this account, never
        // a stored/editable figure. Deliberately no sign-driven color:
        // this is a balance, not a transaction, so it stays neutral --
        // matching `AccountsScreen`'s own plain balance text, unlike
        // `TransactionDetailScreen`'s signed amount.
        Center(
          child: balanceAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
            error: (Object e, StackTrace st) => Icon(Icons.error_outline, color: colors.error),
            data: (Money balance) => AppMoneyText(
              _formatter.format(balance),
              key: const Key('accountCurrentBalance'),
              emphasis: AppMoneyEmphasis.hero,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // [optional useful metadata] -- only fields the model genuinely
        // stores; nothing fabricated (no card issuer/number, statement
        // dates, credit limit, bank connection, or sync state -- none of
        // that exists on `Accounts` today).
        AppCard(
          bordered: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: <Widget>[
              _DetailRow(
                label: l10n.accountOpeningBalanceLabel,
                value: _formatter.format(account.openingBalance),
              ),
              const Divider(height: 1),
              _DetailRow(
                label: l10n.accountCreatedLabel,
                value: DateFormat.yMMMd().format(account.createdAt.toLocal()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // [Recent activity] -- account-scoped, only if it can be shown
        // without any new accounting rule (it can: see
        // `accountRecentActivityProvider`'s doc comment).
        AppSectionHeader(title: l10n.accountRecentActivityTitle, eyebrow: true),
        const SizedBox(height: 8),
        _RecentActivitySection(accountId: account.id),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // Byte-for-byte the same label/value row shape
    // `TransactionDetailScreen`/`GoalDetailScreen` already use.
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

/// The compact recent-activity list -- a `Consumer` of its own so the
/// category providers below (needed only here) don't force
/// [_AccountDetailBody] itself to watch them.
class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection({required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Transaction>> txAsync = ref.watch(accountRecentActivityProvider(accountId));
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    // Same merge-both-types pattern `ActivityScreen` already uses --
    // expense/income each need their own category list; a transfer
    // needs neither.
    final AsyncValue<List<CategoryRow>> expenseCategoriesAsync =
        ref.watch(categoriesForTypeProvider('expense'));
    final AsyncValue<List<CategoryRow>> incomeCategoriesAsync =
        ref.watch(categoriesForTypeProvider('income'));

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace st) => Text(l10n.couldNotLoadAccountDetail('$e')),
      data: (List<Transaction> transactions) {
        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.accountNoRecentActivityMessage,
              style: context.appTypography.secondaryBody,
            ),
          );
        }
        final Map<String, String> accountNames = <String, String>{
          for (final AccountRow a in accountsAsync.valueOrNull ?? const <AccountRow>[]) a.id: a.name,
        };
        final Map<String, CategoryRow> categoriesById = <String, CategoryRow>{
          for (final CategoryRow c in expenseCategoriesAsync.valueOrNull ?? const <CategoryRow>[])
            c.id: c,
          for (final CategoryRow c in incomeCategoriesAsync.valueOrNull ?? const <CategoryRow>[])
            c.id: c,
        };
        return Column(
          children: <Widget>[
            for (final Transaction tx in transactions)
              _AccountActivityRow(
                tx: tx,
                accountId: accountId,
                accountNames: accountNames,
                category: tx.categoryId == null ? null : categoriesById[tx.categoryId],
              ),
          ],
        );
      },
    );
  }
}

/// One recent-activity row, scoped to [accountId] -- reuses
/// [AppFinanceListRow]/[AppMoneyText] exactly like `ActivityScreen`'s own
/// `_TransactionRow`, tappable through to the existing (unmodified)
/// [AppRoutes.transactionDetail] screen.
///
/// [AppFinanceListRow.leadingIcon] takes a plain [IconData], not a
/// widget, so this mirrors `TransactionIconBadge`'s own
/// type/category-icon-name -> [IconData] switch
/// (`transaction_icon_badge.dart`) rather than embedding that widget
/// directly -- same icon per row, resolved the same way, just without a
/// slot to embed the badge widget itself in.
class _AccountActivityRow extends StatelessWidget {
  const _AccountActivityRow({
    required this.tx,
    required this.accountId,
    required this.accountNames,
    required this.category,
  });

  final Transaction tx;
  final String accountId;
  final Map<String, String> accountNames;
  final CategoryRow? category;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isTransfer = tx.type == 'transfer';
    // For a transfer, this account can be either side -- the source
    // (money leaves) or the destination (money arrives). Everywhere
    // else in this app a transfer's amount renders with no sign (it is
    // never counted as income/expense -- ADR-019/ADR-025); here, scoped
    // to ONE account, a directional sign communicates which side THIS
    // account was on, matching the exact same signed treatment
    // `FinanceEngine.accountBalance` already gives a transfer internally
    // -- this is presentation of that existing rule, not a new one.
    final bool isIncomingTransfer = isTransfer && tx.destinationAccountId == accountId;

    final String amountPrefix = switch (tx.type) {
      'income' => '+',
      'transfer' => isIncomingTransfer ? '+' : '-',
      _ => '-',
    };
    final Color amountColor = switch (tx.type) {
      'income' => context.appTokens.colors.positive,
      'transfer' => colors.onSurfaceVariant,
      _ => colors.error,
    };
    final String typeWord = switch (tx.type) {
      'income' => l10n.transactionTypeIncome,
      'transfer' => l10n.transactionTypeTransfer,
      _ => l10n.transactionTypeExpense,
    };
    final String title = switch (tx.type) {
      'transfer' =>
        '${accountNames[tx.accountId] ?? '—'} → ${tx.destinationAccountId == null ? '—' : accountNames[tx.destinationAccountId] ?? '—'}',
      _ => category?.name ?? typeWord,
    };

    final Money amount = Money.fromMinorUnits(tx.amountMinorUnits, tx.currencyCode);
    final String formattedAmount = _formatter.format(amount);
    final String spokenAmount = switch (tx.type) {
      'income' => l10n.spokenPlusAmount(formattedAmount),
      'transfer' => formattedAmount,
      _ => l10n.spokenMinusAmount(formattedAmount),
    };

    // Mirrors `TransactionIconBadge`'s own icon-resolution switch
    // (`transaction_icon_badge.dart`) exactly -- transfer always shows
    // the transfer icon; expense/income with a category shows that
    // category's icon via [categoryIconFor]; expense/income with no
    // category falls back to the same plain minus/plus glyph Activity
    // uses. [AppFinanceListRow.leadingIcon] takes a plain [IconData], so
    // this can't embed `TransactionIconBadge` (a widget) directly -- see
    // the class doc comment.
    final IconData leadingIcon = switch (tx.type) {
      'transfer' => Icons.swap_horiz,
      'income' =>
        category?.icon != null ? categoryIconFor(category!.icon) : Icons.add,
      _ => category?.icon != null ? categoryIconFor(category!.icon) : Icons.remove,
    };

    return AppFinanceListRow(
      leadingIcon: leadingIcon,
      leadingColor: amountColor,
      title: title,
      subtitle: DateFormat.yMMMd().format(tx.occurredAt.toLocal()),
      trailing: Semantics(
        label: spokenAmount,
        excludeSemantics: true,
        child: AppMoneyText(
          '$amountPrefix$formattedAmount',
          emphasis: AppMoneyEmphasis.secondary,
          color: amountColor,
        ),
      ),
      onTap: () => context.push(AppRoutes.transactionDetail(tx.id)),
    );
  }
}
