import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/account_repository.dart' show AccountRowX;
import '../../../core/database/repositories/deposit_repository.dart' show DepositDetailsRowX;
import '../../../core/database/services/account_lifecycle_service.dart';
import '../../../core/finance/deposit_status.dart';
import '../../../core/finance/deposit_term_unit.dart';
import '../../../core/finance/financial_account_subtype.dart';
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

  bool _isCreditCard(AccountRow account) =>
      account.subtypeValue == FinancialAccountSubtype.creditCard;

  /// Account Lifecycle Checkpoint: shows a confirmation dialog (the same
  /// `showDialog<bool>` + `AlertDialog` + cancel/confirm `TextButton`/
  /// `FilledButton` shape `TransactionDetailScreen._confirmDelete`
  /// already uses), and on confirmation calls
  /// `AccountLifecycleService.closeAccount`. [AccountHasActiveRecurringRulesException]
  /// surfaces as [AppLocalizations.accountHasActiveRecurringRulesMessage]
  /// -- a clear, non-technical, actionable message -- rather than a raw
  /// exception; any other failure surfaces via
  /// [AppLocalizations.couldNotCloseAccountMessage]. Never touches
  /// [AccountRow.balanceClass]/[AccountRow.subtype]/
  /// [AccountRow.currencyCode] -- this only ever calls the lifecycle
  /// service, never `updateAccount`.
  Future<void> _confirmClose(
    BuildContext context,
    WidgetRef ref,
    AccountRow account,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isCreditCard = _isCreditCard(account);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          isCreditCard ? l10n.closeCreditCardConfirmTitle : l10n.closeAccountConfirmTitle,
        ),
        content: Text(
          isCreditCard ? l10n.closeCreditCardConfirmMessage : l10n.closeAccountConfirmMessage,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmCloseAccount'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isCreditCard ? l10n.closeCreditCardAction : l10n.closeAccountAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(accountLifecycleServiceProvider).closeAccount(accountId: account.id);
    } on AccountHasActiveRecurringRulesException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountHasActiveRecurringRulesMessage)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotCloseAccountMessage('$e'))),
        );
      }
    }
  }

  /// Mirrors [_confirmClose] for the reverse action -- see
  /// [AccountLifecycleService.reactivateAccount].
  Future<void> _confirmReactivate(
    BuildContext context,
    WidgetRef ref,
    AccountRow account,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.reactivateAccountConfirmTitle),
        content: Text(l10n.reactivateAccountConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmReactivateAccount'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reactivateAccountAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(accountLifecycleServiceProvider).reactivateAccount(accountId: account.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotReactivateAccountMessage('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<AccountRow?> accountAsync = ref.watch(accountByIdProvider(accountId));
    final AccountRow? headerAccount = accountAsync.valueOrNull;
    // Account Lifecycle Checkpoint: `headerAccount` now resolves for a
    // closed account too (see `accountByIdProvider`'s own doc) --
    // `isClosed` below is what the Edit icon and the Close/Reactivate
    // action branch on, not whether `headerAccount` is non-null.
    final bool isClosed = headerAccount != null && headerAccount.deletedAt != null;

    return Scaffold(
      appBar: AppBar(
        // The account's own name is user-entered content and is never
        // translated -- the fallback word shown only while loading (or
        // if the account can't be found) is the only localizable piece
        // here, matching `GoalDetailScreen`'s `goalFallbackTitle`
        // convention.
        title: Text(headerAccount?.name ?? l10n.accountFallbackTitle),
        actions: <Widget>[
          if (headerAccount != null) ...<Widget>[
            // Account Lifecycle Checkpoint: editing a closed account's
            // name/type is out of scope for this checkpoint (and
            // `AccountRepository.updateAccount` already refuses to write
            // to one) -- the Edit icon is simply not offered while
            // closed; Reactivate is the only action shown instead.
            if (!isClosed)
              IconButton(
                key: const Key('editAccount'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editTooltip,
                onPressed: () => context.push(AppRoutes.editAccount(accountId)),
              ),
            IconButton(
              key: const Key('closeOrReactivateAccount'),
              icon: Icon(isClosed ? Icons.restore : Icons.archive_outlined),
              tooltip: isClosed
                  ? l10n.reactivateAccountAction
                  : (_isCreditCard(headerAccount)
                      ? l10n.closeCreditCardAction
                      : l10n.closeAccountAction),
              onPressed: () => isClosed
                  ? _confirmReactivate(context, ref, headerAccount)
                  : _confirmClose(context, ref, headerAccount),
            ),
          ],
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
    final AsyncValue<Money> balanceAsync = ref.watch(accountBalanceProvider(account));
    // Checkpoint L: resolve this account's institution name, if it has
    // one -- see `activeInstitutionsProvider`'s own doc for why this is
    // a local lookup against the watched list rather than a new
    // single-row repository method. Collapses to `null` (never shown)
    // while loading/erroring or if the id doesn't resolve -- this is a
    // secondary metadata field, not the screen's primary content, so it
    // never blocks or shows its own spinner/error state.
    final AsyncValue<List<FinancialInstitutionRow>> institutionsAsync =
        ref.watch(activeInstitutionsProvider);
    String? institutionName;
    if (account.institutionId != null) {
      for (final FinancialInstitutionRow institution
          in institutionsAsync.valueOrNull ?? const <FinancialInstitutionRow>[]) {
        if (institution.id == account.institutionId) {
          institutionName = institution.name;
          break;
        }
      }
    }

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
        // Account Lifecycle Checkpoint: a quiet, unobtrusive status
        // label for a closed account -- never the alarming/destructive
        // styling this design system reserves for an actual error or
        // warning (docs/design guidance: "calm, not alarming"). Shown
        // only once [AccountRow.deletedAt] is set; an active account
        // renders nothing extra here, byte-for-byte the same as before
        // this checkpoint.
        if (account.deletedAt != null) ...<Widget>[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('accountClosedBadge'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.accountClosedLabel,
                style: context.appTypography.caption?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // [large current balance] -- the same derived-from-the-ledger
        // value `AccountsScreen`'s own row shows for this account, never
        // a stored/editable figure. Deliberately no sign-driven color:
        // this is a balance, not a transaction, so it stays neutral --
        // matching `AccountsScreen`'s own plain balance text, unlike
        // `TransactionDetailScreen`'s signed amount.
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Checkpoint L: a small, type-aware label -- driven
              // purely by [AccountRowX.isLiability] (the persisted,
              // authoritative `balanceClass`), never by name/subtype
              // text. "Amount you currently owe" for a liability (the
              // exact same wording Add Account's own credit-card
              // opening-balance field already uses -- reused, not
              // duplicated); "Balance" for every asset (cash, bank,
              // savings, wallet, deposit alike -- deposit's hero number
              // is still a plain ledger balance, not a specially
              // computed principal figure, so it gets no separate
              // label). Makes the hero number underneath unambiguous
              // for a liability without ever flipping its sign or
              // changing the non-negative "amount owed" magnitude
              // `FinanceEngine.accountBalance` already returns.
              Text(
                account.isLiability ? l10n.addAccountAmountOwedLabel : l10n.accountBalanceLabel,
                key: const Key('accountBalanceLabel'),
                textAlign: TextAlign.center,
                style: context.appTypography.caption,
              ),
              const SizedBox(height: 4),
              balanceAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
                error: (Object e, StackTrace st) =>
                    Icon(Icons.error_outline, color: colors.error),
                data: (Money balance) => AppMoneyText(
                  _formatter.format(balance),
                  key: const Key('accountCurrentBalance'),
                  emphasis: AppMoneyEmphasis.hero,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // [optional useful metadata] -- only fields the model genuinely
        // stores; nothing fabricated (no card issuer/number, statement
        // dates, credit limit, bank connection, or sync state -- none of
        // that exists on `Accounts` today). Checkpoint L adds the one
        // exception that DOES already exist: institution name, shown
        // only when `institutionId` is actually set (Cash never has
        // one; every other kind may). `CreditFacilityDetails`'
        // persisted `creditLimitMinorUnits`/`statementClosingDay`/
        // `dueDay` are deliberately still NOT shown here -- genuinely
        // stored, but not yet wired to any presentation anywhere in
        // this app, and out of this checkpoint's explicit scope (see
        // docs/20 §13.15's own note on this).
        AppCard(
          bordered: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: <Widget>[
              // Checkpoint L: only ever shown when the account actually
              // has a persisted institution -- never fabricated, and
              // never shown as an empty/placeholder row otherwise (see
              // `institutionName`'s own resolution above).
              if (institutionName != null && institutionName.isNotEmpty) ...<Widget>[
                _DetailRow(
                  key: const Key('accountInstitutionRow'),
                  label: l10n.accountInstitutionLabel,
                  value: institutionName,
                ),
                const Divider(height: 1),
              ],
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
        // Checkpoint J: a deposit-only card of exactly the fields the
        // persisted `DepositDetails` model actually supports -- see
        // `_DepositDetailsSection`'s own doc for what is (and is
        // deliberately not) shown. Renders nothing at all for every
        // other account subtype, and nothing (not even an empty card)
        // if this deposit account somehow has no details row yet.
        if (account.subtypeValue == FinancialAccountSubtype.deposit) ...<Widget>[
          _DepositDetailsSection(accountId: account.id),
          const SizedBox(height: 24),
        ],
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

/// Checkpoint J (docs/20 §13.14): upgrades the deposit Account Detail
/// with exactly the fields the persisted `DepositDetails` model
/// actually supports -- interest rate, start date, maturity date, term,
/// and a derived Active/Matured status (see `DepositStatus`'s own doc
/// for why status is derived purely from `maturityDate`, independent of
/// [AccountRow.isActive]/`deletedAt`). Deliberately does NOT show
/// `DepositCalculator`'s estimated-interest/estimated-maturity-value
/// figures (out of this checkpoint's scope), does not expose
/// `depositType`/`autoRenew`/`renewalMode`/installment fields (not
/// listed in this checkpoint's required minimum), and never fabricates
/// a status this model cannot support (e.g. "pending funding").
/// "Current/principal information" is already shown above by the
/// existing, generic hero balance + "Opening balance" metadata row --
/// this section does not duplicate either.
class _DepositDetailsSection extends ConsumerWidget {
  const _DepositDetailsSection({required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DepositDetailsRow? details = ref.watch(depositDetailsForAccountProvider(accountId));
    if (details == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    final DateTime today = DateTime.now().toUtc();
    final DateTime todayCalendarOnly = DateTime.utc(today.year, today.month, today.day);
    final DepositStatus status = DepositStatus.fromMaturityDate(
      maturityDateUtc: details.maturityDate,
      nowUtc: todayCalendarOnly,
    );
    final String statusLabel = switch (status) {
      DepositStatus.active => l10n.depositStatusActive,
      DepositStatus.matured => l10n.depositStatusMatured,
    };

    final String termUnitWord = switch (details.termUnitValue) {
      DepositTermUnit.days =>
        details.termNumber == 1 ? l10n.depositTermUnitDay : l10n.depositTermUnitDays,
      DepositTermUnit.months =>
        details.termNumber == 1 ? l10n.depositTermUnitMonth : l10n.depositTermUnitMonths,
      DepositTermUnit.years =>
        details.termNumber == 1 ? l10n.depositTermUnitYear : l10n.depositTermUnitYears,
    };
    // Basis points -> percent with 2 decimal places (550 -> "5.50%").
    // No existing shared percent formatter exists in this codebase
    // (docs/20 §12.8's basis-points representation is otherwise only
    // ever consumed by `DepositCalculator`'s exact-fraction arithmetic,
    // never displayed directly before this checkpoint) -- this is a
    // minimal, local, display-only conversion, not a new shared money/
    // percent abstraction.
    final String interestRateLabel =
        '${(details.interestRateBasisPoints / 100).toStringAsFixed(2)}%';

    return AppCard(
      key: const Key('depositDetailsCard'),
      bordered: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.depositDetailsSectionTitle,
                    style: context.appTypography.secondaryBody,
                  ),
                ),
                Container(
                  key: const Key('depositStatusBadge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: context.appTypography.caption?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _DetailRow(label: l10n.depositInterestRateLabel, value: interestRateLabel),
          const Divider(height: 1),
          _DetailRow(
            label: l10n.depositStartDateLabel,
            value: DateFormat.yMMMd().format(details.startDate),
          ),
          const Divider(height: 1),
          _DetailRow(
            label: l10n.depositMaturityDateLabel,
            value: DateFormat.yMMMd().format(details.maturityDate),
          ),
          const Divider(height: 1),
          _DetailRow(
            label: l10n.depositTermLabel,
            value: '${details.termNumber} $termUnitWord',
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, super.key});
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
    // Account Lifecycle Checkpoint: sourced from `allAccountsProvider`
    // (not `accountsProvider`) so a transfer whose OTHER side is a
    // since-closed account still shows that account's real name here.
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(allAccountsProvider);
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
