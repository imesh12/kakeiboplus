import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/recurring_rule_repository.dart'
    show
        InvalidRecurringRuleAmountException,
        InvalidRecurringRuleNameException,
        RecurringRuleNotFoundException;
import '../../../core/money/currency_mismatch_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_scheduler.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_swipe_action_row.dart';
import '../../../shared/widgets/app_icon_tile.dart';

import '../../../shared/widgets/app_segmented_control.dart';

import '../../../shared/widgets/money_text_field.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/domain/category_color.dart';
import '../../categories/presentation/category_identity_icon.dart';
import '../../categories/presentation/category_providers.dart';
import '../../services/presentation/service_identity_picker.dart';
import '../../services/presentation/service_icon_asset.dart';
import '../domain/recurrence_frequency.dart';
import '../domain/recurring_rule_kind.dart';
import 'recurring_icon_asset.dart';
import 'recurring_providers.dart';
import 'subscription_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// [kind]'s translated label -- reuses the same transaction-type words
/// established for Add/Edit Transaction (`transactionTypeExpense/Income/
/// Transfer`), since a recurring rule's `kind` is the same closed
/// concept (see `RecurringRuleKind`'s own doc comment).
String _kindLabel(AppLocalizations l10n, RecurringRuleKind kind) => switch (kind) {
      RecurringRuleKind.expense => l10n.transactionTypeExpense,
      RecurringRuleKind.income => l10n.transactionTypeIncome,
      RecurringRuleKind.transfer => l10n.transactionTypeTransfer,
    };

/// [frequency]'s translated label. Purely a display concern -- the
/// persisted value (`RecurringRuleRow.frequency`, written via
/// `RecurrenceFrequency.name`) is never touched.
String _frequencyLabel(AppLocalizations l10n, RecurrenceFrequency frequency) => switch (frequency) {
      RecurrenceFrequency.daily => l10n.recurrenceFrequencyDaily,
      RecurrenceFrequency.weekly => l10n.recurrenceFrequencyWeekly,
      RecurrenceFrequency.monthly => l10n.recurrenceFrequencyMonthly,
      RecurrenceFrequency.yearly => l10n.recurrenceFrequencyYearly,
    };

/// Recurring UX checkpoint (full Recurring screen redesign,
/// `docs/14_DECISION_LOG.md` ADR-TBD): presentation-only display order
/// for [RecurringRuleSummary] rows within whichever filter tab/search
/// result is currently shown -- most urgent first (overdue soonest-
/// missed, then due today, then nearest-upcoming), active rules with no
/// current pending item next (the documented pathological-scan edge
/// case on [RecurringRuleSummary.pendingItem]), and expired rules last,
/// each tier broken alphabetically by name for a stable, predictable
/// order. Deliberately NOT a selector in `recurring_providers.dart` --
/// this is a screen-layout decision, not a financial/domain rule, so it
/// stays local to this file rather than widening that module's scope.
int _displayRank(RecurringRuleSummary s) {
  final RecurringItemUrgency? urgency = s.pendingItem?.urgency;
  if (urgency == RecurringItemUrgency.overdue) return 0;
  if (urgency == RecurringItemUrgency.dueToday) return 1;
  if (urgency == RecurringItemUrgency.upcoming) return 2;
  if (s.isActive) return 3;
  return 4; // expired
}

List<RecurringRuleSummary> _sortForDisplay(List<RecurringRuleSummary> summaries) {
  final List<RecurringRuleSummary> sorted = List<RecurringRuleSummary>.of(summaries);
  sorted.sort((RecurringRuleSummary a, RecurringRuleSummary b) {
    final int rankCompare = _displayRank(a).compareTo(_displayRank(b));
    if (rankCompare != 0) return rankCompare;
    final DateTime? dateA = a.pendingItem?.scheduledDateUtc;
    final DateTime? dateB = b.pendingItem?.scheduledDateUtc;
    if (dateA != null && dateB != null) {
      final int dateCompare = dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;
    }
    return a.rule.name.toLowerCase().compareTo(b.rule.name.toLowerCase());
  });
  return sorted;
}

/// The Recurring screen, redesigned (Recurring UX checkpoint) around a
/// single unified list -- see `docs/14_DECISION_LOG.md` ADR-TBD. The
/// prior Checkpoint 11 Recurring/Subscriptions tab split is retired:
/// this screen's new All/Active/Upcoming/Expired filter bar plus the
/// reused, currency-safe estimate card (`subscription_providers.dart`,
/// ADR-031) together supersede what the Subscriptions tab provided, so
/// every active expense rule is simply one more row in this one list
/// rather than a second destination. Reached from the Profile screen's
/// "Recurring" entry and the Home dashboard's recurring summary card --
/// no new bottom-nav item, same precedent Budgets/Savings Goals set.
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(l10n.recurringTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        actions: <Widget>[
          IconButton(
            key: const Key('toggleRecurringSearch'),
            style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface, shape: const CircleBorder()),
            tooltip: _searchActive ? l10n.closeSearchTooltip : l10n.searchTooltip,
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            key: const Key('addRecurringRuleAction'),
            style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, shape: const CircleBorder()),
            tooltip: l10n.addRecurringRuleTooltip,
            icon: const Icon(Icons.add),
            onPressed: () => showDialog<void>(context: context, builder: (_) => const _RuleDialog()),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_searchActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                key: const Key('recurringSearchField'),
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.recurringSearchLabel,
                  hintText: l10n.recurringSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.clearSearchTooltip,
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (String v) => setState(() => _searchQuery = v),
              ),
            ),
          Expanded(child: _RecurringRuleListBody(searchQuery: _searchQuery)),
        ],
      ),
    );
  }
}

/// The unified list body: the reused per-currency estimate card, the
/// All/Active/Upcoming/Expired filter bar, and every rule matching both
/// the selected filter and [searchQuery] as one flat, urgency-ordered
/// list (see [_sortForDisplay]). Owns the filter selection and which
/// row (if any) currently has its swipe-reveal Edit/Delete panel open --
/// both are pure presentation state, reset together whenever the filter
/// changes so a reveal left open under one tab can never silently
/// persist into another.
class _RecurringRuleListBody extends ConsumerStatefulWidget {
  const _RecurringRuleListBody({required this.searchQuery});

  final String searchQuery;

  @override
  ConsumerState<_RecurringRuleListBody> createState() => _RecurringRuleListBodyState();
}

class _RecurringRuleListBodyState extends ConsumerState<_RecurringRuleListBody> {
  RecurringListFilter _filter = RecurringListFilter.all;
  String? _openRuleId;

  void _setFilter(RecurringListFilter filter) {
    setState(() {
      _filter = filter;
      _openRuleId = null;
    });
  }

  void _requestOpen(String ruleId) => setState(() => _openRuleId = ruleId);

  void _requestClose(String ruleId) {
    if (_openRuleId == ruleId) setState(() => _openRuleId = null);
  }

  /// Fired the instant ANY pointer-down interaction begins on rule
  /// [ruleId]'s row -- see `AppSwipeActionRow`'s own `onTapDown` wiring,
  /// which is what actually calls this. This is the fix for a real
  /// cross-row interaction gap: tapping ordinary (non-swipe) content
  /// inside a DIFFERENT, closed row was supposed to close whichever
  /// row is currently open, via the list body's own ancestor
  /// `GestureDetector.onTap` (see the "tap anywhere in the list body"
  /// comment below) -- but that ancestor `onTap` and this specific
  /// row's own `GestureDetector.onTap` (registered for THIS row's
  /// self-tap-closes-self behavior, and for its drag recognizers) sit
  /// in the SAME Flutter gesture arena for that one pointer, and only
  /// one `TapGestureRecognizer` wins an arena at pointer-up -- so the
  /// ancestor's tap can lose and never fire `setState(() =>
  /// _openRuleId = null)` at all, leaving the other row visibly open.
  /// `onTapDown`, unlike `onTap`, fires on EVERY recognizer that is
  /// still a candidate at pointer-DOWN time, before arena resolution
  /// picks a single winner -- so wiring it here reaches the parent
  /// regardless of which recognizer ultimately wins the arena,
  /// without needing the ancestor `GestureDetector` to win anything.
  /// [_openRuleId] stays the single source of truth: this only ever
  /// closes a DIFFERENT row's open panel, never opens [ruleId]'s own
  /// (opening is still exclusively `onOpenRequested`'s job, via a
  /// completed swipe), and does nothing at all when [ruleId] is
  /// already the open row (its own `_handleTap`/`onCloseRequested`
  /// already owns that case).
  void _handleRowInteractionStart(String ruleId) {
    if (_openRuleId != null && _openRuleId != ruleId) {
      setState(() => _openRuleId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokens tokens = context.appTokens;
    final AsyncValue<List<RecurringRuleSummary>> summariesAsync =
        ref.watch(recurringRuleSummariesProvider);
    final AsyncValue<List<SubscriptionCurrencyTotal>> totalsAsync =
        ref.watch(subscriptionEstimatedTotalsProvider);
    final AsyncValue<List<CategoryRow>> expenseCategoriesAsync =
        ref.watch(categoriesForTypeProvider('expense'));
    final AsyncValue<List<CategoryRow>> incomeCategoriesAsync =
        ref.watch(categoriesForTypeProvider('income'));

    if (summariesAsync.isLoading || totalsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (summariesAsync.hasError) {
      return Center(child: Text(l10n.couldNotLoadRecurringRules(summariesAsync.error.toString())));
    }
    if (totalsAsync.hasError) {
      return Center(child: Text(l10n.couldNotLoadRecurringRules(totalsAsync.error.toString())));
    }

    final List<RecurringRuleSummary> allSummaries = summariesAsync.requireValue;
    final List<SubscriptionCurrencyTotal> totals = totalsAsync.requireValue;
    final Map<String, CategoryRow> categoriesById = <String, CategoryRow>{
      for (final CategoryRow c in expenseCategoriesAsync.valueOrNull ?? const <CategoryRow>[]) c.id: c,
      for (final CategoryRow c in incomeCategoriesAsync.valueOrNull ?? const <CategoryRow>[]) c.id: c,
    };
    final DateTime todayUtc = ref.watch(recurringTodayUtcProvider);

    final List<RecurringRuleSummary> filtered =
        selectRecurringRuleSummariesForFilter(allSummaries, _filter, todayUtc);
    final List<RecurringRuleSummary> searched =
        searchRecurringRuleSummaries(filtered, widget.searchQuery, categoriesById);
    final List<RecurringRuleSummary> display = _sortForDisplay(searched);

    return Column(
      children: <Widget>[
        if (totals.isNotEmpty) _EstimateSummaryCard(totals: totals, l10n: l10n),
        Padding(
          padding:
              EdgeInsets.fromLTRB(tokens.spacing.md, tokens.spacing.sm, tokens.spacing.md, tokens.spacing.xxs),
          child: AppSegmentedControl<RecurringListFilter>(
            key: const Key('recurringFilterSegmentedControl'),
            quietTrack: true,
            // Recurring UI Upgrade + History Views checkpoint: a subtle,
            // theme-derived (never a hardcoded hex) two-stop gradient for
            // the selected pill, replacing the flat `colors.primary` fill
            // -- the brief's "more premium using gradients and softer
            // premium states" for the filter row, kept restrained per
            // "do not overdo glow".
            selectedGradient: LinearGradient(
              colors: <Color>[
                Theme.of(context).colorScheme.primary,
                Color.lerp(Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, 0.35)!,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            options: <AppSegmentedControlOption<RecurringListFilter>>[
              AppSegmentedControlOption<RecurringListFilter>(
                value: RecurringListFilter.all,
                label: l10n.recurringFilterAll,
              ),
              AppSegmentedControlOption<RecurringListFilter>(
                value: RecurringListFilter.active,
                label: l10n.recurringFilterActive,
              ),
              AppSegmentedControlOption<RecurringListFilter>(
                value: RecurringListFilter.upcoming,
                label: l10n.recurringStatusUpcoming,
              ),
              AppSegmentedControlOption<RecurringListFilter>(
                value: RecurringListFilter.expired,
                label: l10n.recurringFilterExpired,
              ),
            ],
            selected: _filter,
            onChanged: _setFilter,
          ),
        ),
        Expanded(
          child: GestureDetector(
            // Recurring UX checkpoint (closed-state swipe fix): tapping
            // ANYWHERE in the list body -- including a different, closed
            // row, or blank space below the last row -- closes whichever
            // row's swipe-reveal panel is currently open. A tap that also
            // lands on a specific row's own content (another row's
            // title, a button, empty list space) fires this ancestor
            // `onTap` independently of -- never instead of -- whatever
            // that content's own tap handler does: Flutter gives every
            // `GestureDetector` along the hit-test chain its own arena
            // for a simple tap, so this never suppresses a row's own
            // Edit/Delete/Post/Skip/overflow-menu taps.
            behavior: HitTestBehavior.opaque,
            onTap: _openRuleId == null ? null : () => setState(() => _openRuleId = null),
            child: display.isEmpty
                ? _EmptyRecurringMessage(filter: _filter, hasQuery: widget.searchQuery.trim().isNotEmpty)
                : ListView(
                    key: const Key('recurringRuleListView'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: <Widget>[
                      for (final RecurringRuleSummary summary in display)
                        _RecurringRuleRow(
                          key: Key('recurringRuleRow_${summary.rule.id}'),
                          summary: summary,
                          isOpen: _openRuleId == summary.rule.id,
                          onOpenRequested: () => _requestOpen(summary.rule.id),
                          onCloseRequested: () => _requestClose(summary.rule.id),
                          onInteractionStart: () => _handleRowInteractionStart(summary.rule.id),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyRecurringMessage extends StatelessWidget {
  const _EmptyRecurringMessage({required this.filter, required this.hasQuery});

  final RecurringListFilter filter;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String message = hasQuery
        ? l10n.noMatchingRecurringRulesMessage
        : switch (filter) {
            RecurringListFilter.all => l10n.noRecurringRulesYetTapMessage,
            RecurringListFilter.active => l10n.noActiveRecurringRulesMessage,
            RecurringListFilter.upcoming => l10n.noUpcomingRecurringRulesMessage,
            RecurringListFilter.expired => l10n.noExpiredRecurringRulesMessage,
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          key: const Key('recurringEmptyMessage'),
          textAlign: TextAlign.center,
          style: context.appTypography.secondaryBody,
        ),
      ),
    );
  }
}

/// One estimate card per currency, using the existing expense-only totals.
/// Each card opens the existing all-services yearly history. The history
/// route currently has no currency-scope parameter.
class _EstimateSummaryCard extends StatelessWidget {
  const _EstimateSummaryCard({required this.totals, required this.l10n});

  final List<SubscriptionCurrencyTotal> totals;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('recurringEstimateSummaryCard'),
      children: <Widget>[
        for (final total in totals)
          AppCard(
            key: Key('recurringCurrencySummary_${total.currencyCode}'),
            softShadow: true,
            bordered: true,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.all(12),
            onTap: () => context.push(AppRoutes.recurringHistory),
            child: _EstimateCurrencyBlock(total: total, l10n: l10n),
          ),
      ],
    );
  }
}

class _EstimateCurrencyBlock extends StatelessWidget {
  const _EstimateCurrencyBlock({required this.total, required this.l10n});

  final SubscriptionCurrencyTotal total;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final String monthlyFormatted = _formatter.format(
      Money.fromMinorUnits(total.monthlyEstimateMinorUnits, total.currencyCode),
    );
    final String yearlyFormatted = _formatter.format(
      Money.fromMinorUnits(total.yearlyEstimateMinorUnits, total.currencyCode),
    );

    return Row(
      key: Key('recurringEstimateBlock_${total.currencyCode}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 56,
          height: 68,
          child: Center(
            child: Image.asset(
              RecurringIconAssets.subscriptionSummary,
              width: 46,
              height: 46,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${l10n.recurringEstimateCardTitle} · ${total.currencyCode}',
                style: context.appTypography.caption,
              ),
              const SizedBox(height: 2),
              Text(
                monthlyFormatted,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${l10n.recurringEstimateYearlyTotalLabel}: $yearlyFormatted',
                style: context.appTypography.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// One rule's row in the redesigned Recurring screen -- one row per
/// [RecurringRuleSummary.rule], never per pending occurrence date (see
/// that class's own doc comment in `recurring_providers.dart`). Reuses
/// the exact service > category > kind-based icon/color precedence
/// `_PendingItemTile` established, plus the kind-label badge fallback
/// (an uncategorized income/transfer rule shows "Income"/"Transfer"
/// rather than no badge at all) the Dashboard Upcoming redesign's Part
/// A4 introduced for the same situation -- both screens now agree on
/// what an uncategorized rule's badge shows.
///
/// Edit/Delete moved behind this row's left-swipe reveal panel
/// ([AppSwipeActionRow]); Post/Skip remain exactly as always-visible
/// buttons, unchanged, per the checkpoint's own answered scope
/// question (swipe is additive, not a replacement, for Post/Skip).
class _RecurringRuleRow extends ConsumerStatefulWidget {
  const _RecurringRuleRow({
    required this.summary,
    required this.isOpen,
    required this.onOpenRequested,
    required this.onCloseRequested,
    required this.onInteractionStart,
    super.key,
  });

  final RecurringRuleSummary summary;
  final bool isOpen;
  final VoidCallback onOpenRequested;
  final VoidCallback onCloseRequested;

  /// Forwarded straight through to `AppSwipeActionRow.onInteractionStart`
  /// -- see that field's doc comment and
  /// `_RecurringRuleListBodyState._handleRowInteractionStart` for the
  /// real cross-row-tap fix this is part of.
  final VoidCallback onInteractionStart;

  @override
  ConsumerState<_RecurringRuleRow> createState() => _RecurringRuleRowState();
}

class _RecurringRuleRowState extends ConsumerState<_RecurringRuleRow> {
  bool _isBusy = false;

  RecurringRuleRow get _rule => widget.summary.rule;
  RecurringPendingItem? get _pendingItem => widget.summary.pendingItem;
  String? get _dateKey => _pendingItem?.scheduledDateUtc.toIso8601String();

  Future<void> _handle(Future<void> Function() action) async {
    // Same double-tap re-entrancy guard `_PendingItemTileState._handle`
    // established and ADR-043 documents -- `setState` only schedules a
    // rebuild for the next frame, so a second tap landing before that
    // frame renders must still be blocked here explicitly.
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations dialogL10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(dialogL10n.deleteRecurringRuleConfirmTitle),
          content: Text(dialogL10n.deleteRecurringRuleConfirmMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogL10n.deleteButton),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _handle(() => ref.read(recurringRuleRepositoryProvider).softDelete(_rule.id));
    }
  }

  void _openEditDialog() {
    showDialog<void>(context: context, builder: (_) => _RuleDialog(existingRule: _rule));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final RecurringRuleRow rule = _rule;
    final RecurringPendingItem? pendingItem = _pendingItem;
    final Money amount = Money.fromMinorUnits(rule.amountMinorUnits, rule.currencyCode);
    final RecurringRuleKind kind = RecurringRuleKind.values.byName(rule.kind);
    final bool isTransferRule = kind == RecurringRuleKind.transfer;
    final IconData kindIcon = switch (kind) {
      RecurringRuleKind.expense => Icons.trending_down_rounded,
      RecurringRuleKind.income => Icons.trending_up_rounded,
      RecurringRuleKind.transfer => Icons.swap_horiz_rounded,
    };

    // Best-effort account-name lookup, same convention the old
    // Subscriptions tab's `_SubscriptionsView` used -- never blocks or
    // delays this row on the accounts stream, and never fabricates a
    // name: a `null` here (still loading, or an account since made
    // inactive) simply omits the account segment of the subtitle.
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final String? accountName = accountsAsync.valueOrNull
        ?.cast<AccountRow?>()
        .firstWhere((AccountRow? a) => a?.id == rule.accountId, orElse: () => null)
        ?.name;

    final AsyncValue<CategoryRow>? categoryAsync = (!isTransferRule && rule.categoryId != null)
        ? ref.watch(categoryByIdProvider(rule.categoryId!))
        : null;
    final CategoryRow? category = categoryAsync?.valueOrNull;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String? serviceAsset = isTransferRule ? null : serviceIconAssetFor(rule.serviceIdentityKey);
    final Color leadingColorValue = category != null
        ? categoryColorFor(categoryId: category.id, storedColorKey: category.colorKey, isDark: isDark)
        : colors.onSurfaceVariant;
    final Widget identity = serviceAsset != null
        ? SizedBox(width: 52, height: 52, child: Center(child: Image.asset(
            serviceAsset, width: 40, height: 40, fit: BoxFit.contain,
            filterQuality: FilterQuality.high, excludeFromSemantics: true)))
        : category != null
            ? CategoryIdentityIcon(categoryId: category.id, iconKey: category.icon,
                colorKey: category.colorKey, size: AppIconTileSize.large)
            : AppIconTile(icon: kindIcon, color: leadingColorValue, size: AppIconTileSize.large);
    final instrument = firstActivePaymentInstrumentFor(
      ref.watch(paymentInstrumentsForAccountProvider(rule.accountId)));
    final paymentLabel = <String>[
      if (accountName != null) accountName,
      if (instrument != null && instrument.nickname.trim().isNotEmpty) instrument.nickname,
      if (instrument?.network != null) instrument!.network!,
      if (instrument?.last4 != null) '•••• ${instrument!.last4}',
    ].join(' · ');
    // Recurring UX checkpoint Part A4's kind-label badge fallback,
    // reused verbatim here so the Dashboard Upcoming card and this
    // screen agree on what an uncategorized rule's badge shows: a real
    // resolved category always wins; otherwise an income/transfer rule
    // shows its kind as the badge, and an uncategorized expense rule
    // shows no badge at all (never fabricated).
    final String? badgeLabel =
        category?.name ??
        (kind == RecurringRuleKind.expense ? null : _kindLabel(l10n, kind));
    final badgeStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
      fontSize: 10,
      height: 1.15,
      fontWeight: FontWeight.w500,
      color: leadingColorValue,
    );
    final Widget? badge = badgeLabel == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: leadingColorValue.withValues(alpha: 0.12),
              borderRadius: context.appTokens.radii.pillRadius,
            ),
            child: Text(badgeLabel, style: badgeStyle, softWrap: true),
          );
    final String? urgencyChipLabel = switch (pendingItem?.urgency) {
      RecurringItemUrgency.overdue => l10n.overdueLabel,
      RecurringItemUrgency.dueToday => l10n.recurringStatusDueToday,
      RecurringItemUrgency.upcoming || null => null,
    };
    final Color urgencyChipColor = switch (pendingItem?.urgency) {
      RecurringItemUrgency.overdue => colors.error,
      RecurringItemUrgency.dueToday => colors.primary,
      RecurringItemUrgency.upcoming || null => colors.onSurfaceVariant,
    };

    final String frequencyLabel = _frequencyLabel(l10n, RecurrenceFrequency.values.byName(rule.frequency));
    final String nextDateLabel = widget.summary.isExpired
        ? l10n.recurringEndedLabel
        : DateFormat.yMMMd().format(widget.summary.nextOccurrenceUtc!);
    final tokens = context.appTokens;
    final text = Theme.of(context).textTheme;
    Widget actionSurface(
      Widget button,
      List<Color>? gradient,
      Color fallback,
    ) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: tokens.radii.pillRadius,
        gradient: LinearGradient(
          colors: gradient ?? <Color>[fallback, fallback],
        ),
      ),
      child: button,
    );
    final Widget rowContent = Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(width: 52, child: Center(child: identity)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = Text(
                      rule.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    double labelWidth(String label, TextStyle? style) {
                      final painter = TextPainter(
                        text: TextSpan(text: label, style: style),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout();
                      final width = painter.width;
                      painter.dispose();
                      return width;
                    }

                    final requiredWidth =
                        labelWidth(rule.name, title.style) +
                        (badgeLabel == null
                            ? 0
                            : labelWidth(badgeLabel, badgeStyle) + 14);
                    if (requiredWidth > constraints.maxWidth) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[title, if (badge != null) badge],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Flexible(child: title),
                        if (badge != null) ...<Widget>[
                          const SizedBox(width: 4),
                          badge,
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 1),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _formatter.format(amount),
                      style: text.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '/ $frequencyLabel',
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      widget.summary.isExpired
                          ? nextDateLabel
                          : l10n.recurringNextDateLabel(nextDateLabel),
                      style: context.appTypography.caption?.copyWith(
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                    if (urgencyChipLabel != null)
                      Text(
                        urgencyChipLabel,
                        style: text.labelSmall?.copyWith(
                          fontSize: 10,
                          height: 1.2,
                          color: urgencyChipColor,
                        ),
                      ),
                  ],
                ),
                if (paymentLabel.isNotEmpty)
                  Row(
                    children: <Widget>[
                      Icon(
                        instrument == null
                            ? Icons.account_balance_wallet_outlined
                            : Icons.credit_card,
                        size: 12,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          paymentLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTypography.caption,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (pendingItem != null) ...<Widget>[
                  actionSurface(
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(54, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.transparent,
                        foregroundColor: colors.onPrimary,
                        textStyle: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      key: Key('postOccurrence_${rule.id}_$_dateKey'),
                      onPressed: _isBusy
                          ? null
                          : () => _handle(
                              () => ref
                                  .read(recurringOccurrenceRepositoryProvider)
                                  .postOccurrence(
                                    ruleId: rule.id,
                                    scheduledDateUtc:
                                        pendingItem.scheduledDateUtc,
                                  ),
                            ),
                      child: Text(l10n.postButton),
                    ),
                    tokens.colors.positiveGradient,
                    colors.primary,
                  ),
                  const SizedBox(height: 4),
                  actionSurface(
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(54, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.transparent,
                        foregroundColor: colors.onError,
                        side: BorderSide.none,
                        textStyle: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      key: Key('skipOccurrence_${rule.id}_$_dateKey'),
                      onPressed: _isBusy
                          ? null
                          : () => _handle(
                              () => ref
                                  .read(recurringOccurrenceRepositoryProvider)
                                  .skipOccurrence(
                                    ruleId: rule.id,
                                    scheduledDateUtc:
                                        pendingItem.scheduledDateUtc,
                                  ),
                            ),
                      child: Text(l10n.skipButton),
                    ),
                    tokens.colors.negativeGradient,
                    colors.error,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final Widget foregroundCard = AppCard(
      key: Key('pendingItem_${rule.id}_$_dateKey'),
      bordered: true,
      padding: EdgeInsets.zero,
      child: rowContent,
    );

    // Recurring History Final Corrections checkpoint: the row itself is
    // now the primary Case 2 navigation target (see
    // `AppSwipeActionRow.onForegroundTap` below), so there is no longer a
    // separate always-visible history button for a screen reader to
    // land on. `Semantics` adds the missing accessible action/label
    // directly to the foreground card WITHOUT excluding its own
    // descendant semantics (the rule's name/amount/next-date text must
    // still be announced) -- it merges in alongside them. Only applied
    // while the row is CLOSED: while open, a tap closes the reveal
    // panel instead (see [AppSwipeActionRowState._handleTap]), and the
    // two reveal actions already carry their own explicit `Semantics`
    // labels (`_RevealActionButton`), so nothing here should claim to
    // be a "view history" affordance in that state.
    final Widget accessibleForegroundCard = Semantics(
      key: Key('ruleSemanticActions_${rule.id}'),
      container: true,
      button: !widget.isOpen,
      label: widget.isOpen ? null : l10n.recurringViewHistoryTooltip,
      customSemanticsActions: _isBusy
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: l10n.editTooltip): _openEditDialog,
              CustomSemanticsAction(label: l10n.deleteRuleTooltip): () =>
                  unawaited(_confirmDelete()),
            },
      child: foregroundCard,
    );
    return AppSwipeActionRow(
      editActionKey: ValueKey('recurringEditAction_${rule.id}'),
      deleteActionKey: ValueKey('recurringDeleteAction_${rule.id}'),
      isOpen: widget.isOpen,
      onOpenRequested: widget.onOpenRequested,
      onCloseRequested: widget.onCloseRequested,
      onInteractionStart: widget.onInteractionStart,
      onEdit: _openEditDialog,
      onDelete: () => unawaited(_confirmDelete()),
      editLabel: l10n.editTooltip,
      deleteLabel: l10n.deleteRuleTooltip,
      // Recurring History Final Corrections checkpoint (Case 2): a
      // closed row's ordinary foreground tap now opens this rule's own
      // history -- see `AppSwipeActionRow.onForegroundTap`'s own doc
      // comment for the full open/closed contract and why this can
      // never also fire for Post/Skip/overflow/the reveal actions.
      onForegroundTap: () => context.push(AppRoutes.recurringRuleHistory(rule.id)),
      // Closed-state bleed fix: this margin now lives on the OUTSIDE of
      // the whole swipe stack (see `AppSwipeActionRow`'s own doc comment)
      // instead of on this `AppCard` alone -- previously the background
      // reveal panels filled this row's full, un-margined bounds while
      // this margined card left a transparent gap on every edge that
      // they showed through, even at rest.
      margin: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: accessibleForegroundCard,
    );
  }
}

/// Recurring UX checkpoint (two-directional redesign): a swipe-reveal
/// row exposing Edit (drag left-to-right -- positive `dx` -- reveals a
/// panel on the LEFT) and Delete (drag right-to-left -- negative `dx`
/// -- reveals a panel on the RIGHT) behind the row's content. Built
/// from scratch -- `pubspec.yaml` has no slidable/swipe package, and
/// `Dismissible` is the wrong shape anyway (it swipes a row fully
/// off-screen to delete it; this is a persistent reveal the user can
/// tap into, not a dismiss-to-delete gesture).
///
/// # Closed-state bleed fix
///
/// [margin] is applied ONCE here, as the OUTERMOST [Padding] wrapping
/// both the background action panels and the foreground card -- never
/// as the foreground [AppCard]'s own `margin` (that was the previous,
/// buggy shape: the background panels filled this widget's full,
/// un-margined bounds while the margined foreground card left a
/// transparent gap on every edge -- left, right, top, AND bottom --
/// that the background showed through even at rest, `_dragExtent ==
/// 0`). With the margin applied outside instead, the Stack's own
/// bounds are now IDENTICAL to the visible card's bounds: the
/// foreground has no margin of its own left to create a gap on any
/// edge. The whole Stack is additionally wrapped in one [ClipRRect]
/// (radius matching [AppCard]'s own default radius, since the
/// `AppCard` below never overrides it) so a revealed action panel's
/// square corners can never peek outside the row's rounded outline
/// either -- both together are what "closed row renders ONLY the
/// normal row, never a colored rail/line at any edge" actually
/// requires.
///
/// # Interaction, not just paint order
///
/// Each action panel is wrapped in [IgnorePointer] whenever its own
/// side isn't at least partially dragged open (see
/// [AppSwipeActionRowState.build]) -- being fully covered by the opaque
/// foreground at `_dragExtent == 0` only guarantees nothing is PAINTED
/// on top; Flutter's hit-testing does not stop at the first opaque
/// widget in a `Stack`, so without this, a tap at the (invisible)
/// Delete button's location would still have reached its `InkWell`
/// underneath. [IgnorePointer] is what makes the closed row's action
/// surface genuinely unreachable, not merely unseen.
///
/// Exactly one row may be open at a time across the whole list --
/// [isOpen]/[onOpenRequested]/[onCloseRequested] are fully controlled by
/// the parent ([_RecurringRuleListBodyState]'s single `_openRuleId`
/// field) rather than this widget holding its own notion of "am I
/// open", so opening a second row always closes whichever one was open
/// first. WHICH side (Edit or Delete) is open is this widget's own
/// internal state ([AppSwipeActionRowState._openExtent]) -- the parent
/// only ever needs to know "is this row the open one", never which
/// side; dragging from one side's fully-open position past the
/// opposite threshold (see [AppSwipeActionRowState._onDragEnd]) smoothly
/// replaces whichever side was open with the other, continuously, with
/// no separate "close first" step.
///
/// The always-available, fully semantic overflow menu
/// (row custom semantic actions) remains the universal
/// accessibility fallback for both actions, regardless of gesture
/// direction or locale.
/// Create (no [existingRule]) or edit (an active [existingRule]) a
/// recurring rule. [RecurringRuleKind] is chosen only when creating --
/// see `RecurringRuleRepository.updateRule`'s doc comment for why it's
/// permanently fixed afterward.
class _RuleDialog extends ConsumerStatefulWidget {
  const _RuleDialog({this.existingRule});
  final RecurringRuleRow? existingRule;

  @override
  ConsumerState<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends ConsumerState<_RuleDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _intervalController;
  late final TextEditingController _noteController;
  late RecurringRuleKind _kind;
  late RecurrenceFrequency _frequency;
  String? _accountId;
  String? _destinationAccountId;
  String? _categoryId;
  String? _serviceIdentityKey;
  Money? _parsedAmount;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _notificationsEnabled = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    final RecurringRuleRow? existing = widget.existingRule;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _intervalController = TextEditingController(text: '${existing?.interval ?? 1}');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _kind = existing == null ? RecurringRuleKind.expense : RecurringRuleKind.values.byName(existing.kind);
    _frequency = existing == null
        ? RecurrenceFrequency.monthly
        : RecurrenceFrequency.values.byName(existing.frequency);
    _accountId = existing?.accountId;
    _destinationAccountId = existing?.destinationAccountId;
    _categoryId = existing?.categoryId;
    _serviceIdentityKey = existing?.serviceIdentityKey;
    _startDate = existing?.startDate ?? DateTime.now().toUtc();
    _endDate = existing?.endDate;
    _notificationsEnabled = existing?.notificationsEnabled ?? false;
    // `MoneyTextField` only calls `onParsed` in response to the user
    // typing (see its `onChanged: _tryParse`) or a currency change via
    // `didUpdateWidget` -- it never parses its own `initialValue` on
    // first build. Without seeding `_parsedAmount` here, editing an
    // existing rule without touching the amount field left it `null`,
    // which made `_submit` silently return at its
    // `if (amount == null || ...) return;` guard -- Save appeared to do
    // nothing and the dialog never closed.
    _parsedAmount =
        existing == null ? null : Money.fromMinorUnits(existing.amountMinorUnits, existing.currencyCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (isStart ? _startDate : _endDate) ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  /// Handles the "Remind me" switch. Per Beta 1 Task 4B correction 3:
  /// notification permission is requested ONLY here -- the direct,
  /// synchronous result of the user turning this toggle on -- never at
  /// app startup, during reconciliation, or merely because this dialog
  /// opened (`initState` above only READS the persisted value, it never
  /// calls this). Turning the toggle off never needs permission at all.
  ///
  /// If permission isn't granted, reverts to off (per the user's stated
  /// preference: persisted state should reflect actually-usable
  /// behavior) and shows a concise, one-time message -- no crash, no
  /// repeated automatic prompt (the OS itself won't re-prompt once
  /// denied; this handler only ever asks again if the user taps the
  /// switch on again themselves).
  Future<void> _onNotificationsToggled(bool wantsEnabled) async {
    if (!wantsEnabled) {
      setState(() => _notificationsEnabled = false);
      return;
    }
    final NotificationScheduler scheduler = ref.read(notificationSchedulerProvider);
    final NotificationPermissionStatus status = await scheduler.requestPermission();
    if (!mounted) return;
    if (status == NotificationPermissionStatus.granted) {
      setState(() => _notificationsEnabled = true);
    } else {
      setState(() => _notificationsEnabled = false);
      final AppLocalizations l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsPermissionDeniedMessage)),
      );
    }
  }

  /// Destination accounts eligible for a transfer FROM
  /// [sourceAccountId]: not the source account itself, and the same
  /// currency -- Beta 1 Task 4A does not support FX/cross-currency
  /// recurring transfers (see
  /// `RecurringRuleRepository._validateAccounts`, which enforces this
  /// independently of this filter and remains the authoritative check;
  /// this is convenience-only, same precedent as
  /// `_DestinationAccountDropdown` in `add_transaction_screen.dart`
  /// (ADR-019)). [accounts] is already profile-scoped, active-only
  /// via `accountsProvider`, so no further eligibility filtering is
  /// needed here.
  List<AccountRow> _eligibleDestinationAccounts(List<AccountRow> accounts, String? sourceAccountId) {
    AccountRow? source;
    for (final AccountRow candidate in accounts) {
      if (candidate.id == sourceAccountId) {
        source = candidate;
        break;
      }
    }
    // Copied to a non-nullable local before the closure below -- Dart
    // does not carry null-promotion of a captured variable into a
    // closure.
    final AccountRow? sourceAccount = source;
    if (sourceAccount == null) return const <AccountRow>[];
    return accounts
        .where((a) => a.id != sourceAccount.id && a.currencyCode == sourceAccount.currencyCode)
        .toList(growable: false);
  }

  Future<void> _submit(List<AccountRow> accounts) async {
    // Re-entrancy guard against a double-tap/rapid-repeat Save -- same
    // hazard and same fix as `_PendingItemTileState._handle` above and
    // the Checkpoint S savings-goal dialogs (ADR-042). Unlike posting/
    // skipping an occurrence, `RecurringRuleRepository.createRule`/
    // `.updateRule` have no natural uniqueness key to reject a duplicate
    // call with -- two concurrent Saves before this dialog disables its
    // button would genuinely create two separate recurring rules (or
    // apply the same edit twice). This check must be the very first
    // thing `_submit` does, before any validation, so a second call
    // that reaches this point while the first is still in flight returns
    // immediately. See `docs/14_DECISION_LOG.md` ADR-043.
    if (_isSaving) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final Money? amount = _parsedAmount;
    final String? accountId = _accountId;
    final DateTime? startDate = _startDate;
    if (amount == null || accountId == null || startDate == null) return;
    if (_kind == RecurringRuleKind.transfer && _destinationAccountId == null) {
      setState(() => _errorMessage = l10n.chooseDestinationAccount);
      return;
    }
    final int? interval = int.tryParse(_intervalController.text.trim());
    if (interval == null) return;

    setState(() => _isSaving = true);
    try {
      final String note = _noteController.text.trim();
      if (_isEditing) {
        await ref.read(recurringRuleRepositoryProvider).updateRule(
              id: widget.existingRule!.id,
              name: _nameController.text,
              amount: amount,
              accountId: accountId,
              destinationAccountId: _kind == RecurringRuleKind.transfer
                  ? Value<String?>(_destinationAccountId)
                  : const Value<String?>.absent(),
              categoryId: _kind == RecurringRuleKind.transfer
                  ? const Value<String?>(null)
                  : Value<String?>(_categoryId),
              serviceIdentityKey: _kind == RecurringRuleKind.transfer
                  ? const Value<String?>(null)
                  : Value<String?>(_serviceIdentityKey),
              note: Value<String?>(note.isEmpty ? null : note),
              frequency: _frequency,
              interval: interval,
              startDate: startDate,
              endDate: Value<DateTime?>(_endDate),
              notificationsEnabled: Value<bool>(_notificationsEnabled),
            );
      } else {
        final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
        if (profile == null) return;
        await ref.read(recurringRuleRepositoryProvider).createRule(
              profileId: profile.id,
              kind: _kind,
              name: _nameController.text,
              amount: amount,
              accountId: accountId,
              destinationAccountId: _kind == RecurringRuleKind.transfer ? _destinationAccountId : null,
              categoryId: _kind == RecurringRuleKind.transfer ? null : _categoryId,
              serviceIdentityKey: _kind == RecurringRuleKind.transfer ? null : _serviceIdentityKey,
              note: note.isEmpty ? null : note,
              frequency: _frequency,
              interval: interval,
              startDate: startDate,
              endDate: _endDate,
              notificationsEnabled: _notificationsEnabled,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on CurrencyMismatchException catch (e) {
      // Belt-and-braces: the destination dropdown already only offers
      // same-currency accounts (see `_eligibleDestinationAccounts`
      // above), but the repository enforces this independently -- see
      // `RecurringRuleRepository._validateAccounts` -- so surface its
      // rejection cleanly rather than letting it crash the dialog. This
      // is exactly the bug manual Android testing found: Save appeared
      // unresponsive because this exception was previously unhandled.
      setState(() {
        _errorMessage =
            l10n.transfersCrossCurrencyNotSupportedMessage(e.currencyCodeA, e.currencyCodeB);
      });
    } on InvalidRecurringRuleAmountException catch (e) {
      setState(() => _errorMessage = e.toString());
    } on InvalidRecurringRuleNameException catch (e) {
      setState(() => _errorMessage = e.toString());
    } on RecurringRuleNotFoundException catch (e) {
      setState(() => _errorMessage = e.toString());
    } on ArgumentError catch (e) {
      // Covers the repository's own input-validation checks that use
      // `ArgumentError` (interval, end date, same source/destination
      // account, unsupported currency) -- see
      // `RecurringRuleRepository._validateAccounts`/`_validateInterval`/
      // `_validateDateRange`. Deliberately NOT a bare `catch` -- an
      // unexpected error (a real bug) should still surface as an
      // unhandled exception rather than being swallowed here.
      setState(() => _errorMessage = (e.message ?? 'Invalid value.').toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final List<AccountRow> accounts = accountsAsync.valueOrNull ?? const <AccountRow>[];
    final AccountRow? selectedAccount =
        accounts.where((a) => a.id == _accountId).cast<AccountRow?>().firstWhere(
              (a) => true,
              orElse: () => accounts.isEmpty ? null : accounts.first,
            );
    final String amountCurrency = selectedAccount?.currencyCode ?? 'JPY';
    final String categoryType = _kind == RecurringRuleKind.income ? 'income' : 'expense';
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider(categoryType));
    final List<AccountRow> eligibleDestinationAccounts = _kind == RecurringRuleKind.transfer
        ? _eligibleDestinationAccounts(accounts, _accountId)
        : const <AccountRow>[];
    // Only meaningful once a source account is actually chosen -- before
    // that, the source dropdown's own "Choose an account." validator is
    // what blocks Save, not this.
    final bool noEligibleDestination =
        _kind == RecurringRuleKind.transfer && _accountId != null && eligibleDestinationAccounts.isEmpty;
    final Widget? destinationField = _kind != RecurringRuleKind.transfer || _accountId == null
        ? null
        : eligibleDestinationAccounts.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.noSameCurrencyDestinationMessage,
                  key: const Key('noEligibleDestinationMessage'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            : DropdownButtonFormField<String>(
                key: const Key('recurringDestinationAccountDropdown'),
                initialValue: eligibleDestinationAccounts.any((a) => a.id == _destinationAccountId)
                    ? _destinationAccountId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.destinationAccountLabel),
                items: <DropdownMenuItem<String>>[
                  for (final AccountRow account in eligibleDestinationAccounts)
                    DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        '${account.name} (${account.currencyCode})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? v) => setState(() => _destinationAccountId = v),
                validator: (String? v) => v == null ? l10n.chooseDestinationAccount : null,
              );

    final ColorScheme colors = Theme.of(context).colorScheme;
    // Premium Create/Edit Rule checkpoint: one cascading field theme for
    // every existing `TextFormField`/`DropdownButtonFormField`/
    // `MoneyTextField` below -- none of them set their own `border`, so
    // this is a presentation-only wrapper. Every field keeps its exact
    // key, validator, items, and onChanged callback; only the shared
    // visual shell (filled, rounded, theme-derived colors) changes.
    final ThemeData premiumFieldTheme = Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),
    );
    // Theme-derived (never a hardcoded hex), same two-stop formula
    // `recurringFilterSegmentedControl`'s own selected-pill gradient
    // already established in this file -- restrained, on-brand, and
    // automatically correct for every theme (Light/Dark/Pink/Ocean/
    // Forest) since it is only ever built from `colorScheme.primary`/
    // `secondary`.
    final LinearGradient saveButtonGradient = LinearGradient(
      colors: <Color>[
        colors.primary,
        Color.lerp(colors.primary, colors.secondary, 0.35)!,
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    final bool saveDisabled = _isSaving || noEligibleDestination;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Text(
                _isEditing ? l10n.editRecurringRuleTitle : l10n.newRecurringRuleTitle,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: Theme(
                data: premiumFieldTheme,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // --- Basic Details -----------------------------
                        if (!_isEditing)
                          DropdownButtonFormField<RecurringRuleKind>(
                            key: const Key('recurringKindDropdown'),
                            initialValue: _kind,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l10n.recurringKindFieldLabel),
                            items: <DropdownMenuItem<RecurringRuleKind>>[
                              for (final RecurringRuleKind kind in RecurringRuleKind.values)
                                DropdownMenuItem<RecurringRuleKind>(
                                  value: kind,
                                  child: Text(_kindLabel(l10n, kind), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (RecurringRuleKind? v) => setState(() {
                              _kind = v ?? _kind;
                              _categoryId = null;
                              _serviceIdentityKey = null;
                              _destinationAccountId = null;
                            }),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${l10n.recurringKindFieldLabel}: ${_kindLabel(l10n, _kind)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('recurringNameField'),
                          controller: _nameController,
                          decoration: InputDecoration(labelText: l10n.recurringRuleNameLabel),
                          validator: (String? v) =>
                              (v == null || v.trim().isEmpty) ? l10n.enterRecurringRuleNameMessage : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          key: const Key('recurringAccountDropdown'),
                          initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _kind == RecurringRuleKind.transfer
                                ? l10n.sourceAccountLabel
                                : l10n.accountLabel,
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
                          onChanged: (String? v) => setState(() {
                            _accountId = v;
                            // Requirement 2: if the previously selected
                            // destination is no longer eligible under the
                            // new source account (different account,
                            // different currency), clear it -- never leave
                            // a stale, now-invalid destination selected
                            // just because the dropdown itself re-renders
                            // without it as an option.
                            final List<AccountRow> stillEligible =
                                _eligibleDestinationAccounts(accounts, v);
                            if (_destinationAccountId != null &&
                                !stillEligible.any((a) => a.id == _destinationAccountId)) {
                              _destinationAccountId = null;
                            }
                          }),
                          validator: (String? v) => v == null ? l10n.chooseAccountMessage : null,
                        ),
                        if (destinationField != null) ...<Widget>[
                          const SizedBox(height: 14),
                          destinationField,
                        ],
                        const SizedBox(height: 20),
                        Divider(color: colors.outlineVariant),
                        const SizedBox(height: 20),
                        // --- Classification (non-transfer only) --------
                        if (_kind != RecurringRuleKind.transfer)
                          categoriesAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (Object e, StackTrace st) => const SizedBox.shrink(),
                            data: (List<CategoryRow> categories) => DropdownButtonFormField<String?>(
                              key: const Key('recurringCategoryDropdown'),
                              initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: l10n.categoryOptionalLabel),
                              items: <DropdownMenuItem<String?>>[
                                DropdownMenuItem<String?>(value: null, child: Text(l10n.noneOptionLabel)),
                                for (final CategoryRow category in categories)
                                  DropdownMenuItem<String?>(
                                    value: category.id,
                                    // Checkpoint U1: see `_CategoryDropdown`'s
                                    // identical comment in
                                    // `add_transaction_screen.dart` -- the
                                    // same `CategoryIdentityIcon` widget, so
                                    // this rule dialog's category choice
                                    // renders identically to every other
                                    // category surface in the app.
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        CategoryIdentityIcon(
                                          categoryId: category.id,
                                          iconKey: category.icon,
                                          colorKey: category.colorKey,
                                          size: AppIconTileSize.small,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(category.name, overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (String? v) => setState(() => _categoryId = v),
                            ),
                          ),
                        if (_kind != RecurringRuleKind.transfer) ...<Widget>[
                          const SizedBox(height: 14),
                          // Checkpoint U2: category identity and service
                          // identity are independent, optional selections
                          // here too -- same convention and same widget as
                          // `add_transaction_screen.dart`'s dropdown, never
                          // shown for a transfer.
                          ServiceIdentityDropdown(
                            value: _serviceIdentityKey,
                            onChanged: (String? key) => setState(() => _serviceIdentityKey = key),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_kind != RecurringRuleKind.transfer) ...<Widget>[
                          Divider(color: colors.outlineVariant),
                          const SizedBox(height: 20),
                        ],
                        // --- Amount & Schedule --------------------------
                        MoneyTextField(
                          key: const Key('recurringAmountField'),
                          currencyCode: amountCurrency,
                          label: l10n.amountLabel,
                          initialValue: widget.existingRule == null
                              ? null
                              : Money.fromMinorUnits(widget.existingRule!.amountMinorUnits, amountCurrency)
                                  .toMajorUnitsString(),
                          onParsed: (Money? m) => _parsedAmount = m,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<RecurrenceFrequency>(
                          key: const Key('recurringFrequencyDropdown'),
                          initialValue: _frequency,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l10n.frequencyLabel),
                          items: <DropdownMenuItem<RecurrenceFrequency>>[
                            for (final RecurrenceFrequency freq in RecurrenceFrequency.values)
                              DropdownMenuItem<RecurrenceFrequency>(
                                value: freq,
                                child: Text(_frequencyLabel(l10n, freq), overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (RecurrenceFrequency? v) => setState(() => _frequency = v ?? _frequency),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('recurringIntervalField'),
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l10n.intervalLabel),
                          validator: (String? v) {
                            final int? parsed = int.tryParse((v ?? '').trim());
                            if (parsed == null || parsed < 1) return l10n.enterWholeNumberMessage;
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Material(
                          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            key: const Key('pickRecurringStartDate'),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: Icon(Icons.calendar_today_outlined, color: colors.primary),
                            title: Text(
                              _startDate == null
                                  ? l10n.chooseStartDateMessage
                                  : '${l10n.startDateLabel}: ${DateFormat.yMMMd().format(_startDate!)}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: Icon(Icons.event_outlined, color: colors.onSurfaceVariant),
                            title: Text(
                              _endDate == null
                                  ? l10n.noEndDateMessage
                                  : '${l10n.endDateLabel}: ${DateFormat.yMMMd().format(_endDate!)}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                TextButton(
                                  key: const Key('pickRecurringEndDate'),
                                  onPressed: () => _pickDate(isStart: false),
                                  child: Text(l10n.chooseButton),
                                ),
                                if (_endDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    tooltip: l10n.clearEndDateTooltip,
                                    onPressed: () => setState(() => _endDate = null),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: colors.outlineVariant),
                        const SizedBox(height: 20),
                        // --- Reminder ------------------------------------
                        Material(
                          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          child: SwitchListTile(
                            key: const Key('recurringNotificationsToggle'),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            secondary: Icon(Icons.notifications_outlined, color: colors.primary),
                            title: Text(l10n.remindMeLabel),
                            subtitle: Text(l10n.remindMeSubtitle),
                            value: _notificationsEnabled,
                            onChanged: (bool v) => unawaited(_onNotificationsToggled(v)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(labelText: l10n.noteOptionalLabel),
                        ),
                        if (_errorMessage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            key: const Key('recurringFormErrorMessage'),
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: colors.onSurfaceVariant,
                      ),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: saveDisabled ? null : saveButtonGradient,
                        color: saveDisabled ? colors.surfaceContainerHighest : null,
                      ),
                      child: FilledButton(
                        key: const Key('saveRecurringRule'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: saveDisabled ? null : () => _submit(accounts),
                        child: Text(l10n.save),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
