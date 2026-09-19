import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/fx/fx_converter.dart';
import '../../../core/fx/reference_fx_rate_providers.dart';
import '../../../core/fx/reference_rate_result.dart';
import '../../../core/fx/reference_rate_view.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/money/money_overflow_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/money_text_field.dart';
import '../../onboarding/presentation/profile_providers.dart';
import 'favorite_currency_pairs_provider.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Checkpoint 9.6: a V1 Currency Converter -- informational/reference
/// only, built entirely on the CP9.1-CP9.5 FX engine with no new
/// conversion logic of its own.
///
/// # This is NOT accounting
///
/// This screen never creates a `Transactions` row, never touches an
/// account balance/budget/goal/income/expense figure, and never feeds a
/// value back into `TransactionExchangeRates` (the historical, per-
/// transaction snapshot table -- see that table's own doc for why it must
/// stay architecturally separate from this reference-only surface).
/// Cross-currency transfers remain rejected exactly as before; nothing
/// here creates a way around that.
///
/// # Ordered-pair semantics, never inverted
///
/// Exactly like [ReferenceRateCard] and Home's `_LivingCurrencyEquivalentLine`,
/// this screen always requests `referenceRateProvider((from, to))` --
/// never `(to, from)` reinterpreted, never a client-side `1 / rate`
/// reciprocal. Swapping From/To (Task 7) issues a genuinely new ordered-
/// pair request; see [_swap]'s own doc for the exact decision.
///
/// # Amount changes never trigger a new FX request (Task 9)
///
/// The reference-rate watch is keyed by `(fromCurrency, toCurrency)`
/// alone -- [_amount] is not part of that key, so typing `1`, `10`, `100`,
/// `1000` recomputes the converted result with pure local
/// [FxConverter.convert] math on every keystroke without ever causing a
/// new provider/network call. Only an actual currency-pair change (typing
/// a new From/To, swapping, or picking a favorite) requests a different
/// pair.
class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

/// V1 cap on the number of saved favorite pairs -- Task 12. Deterministic
/// (no silent eviction): once reached, adding a new favorite is refused
/// outright with [AppLocalizations.favoritePairsLimitReachedMessage]
/// rather than quietly dropping the oldest one.
const int _favoritePairsLimit = 6;

class _CurrencyConverterScreenState extends ConsumerState<CurrencyConverterScreen> {
  static final List<String> _currencyCodes =
      CurrencyRegistry.seed.map((Currency c) => c.code).toList();

  bool _seeded = false;
  String? _fromCurrency;
  String? _toCurrency;
  Money? _amount;

  /// Seeds From/To exactly once, from the profile's home/living currency
  /// (Task 14's preferred default pair) -- never re-seeded afterwards,
  /// even if the profile stream re-emits, so a user's in-progress
  /// From/To/amount selections on this screen are never silently reset
  /// out from under them. Falls back to the first known
  /// [CurrencyRegistry] currency for either side if the persisted profile
  /// value somehow isn't a currency this registry recognizes (mirrors
  /// `_LivingCurrencyEquivalentLine`'s identical defensive guard) --
  /// purely a crash-safety fallback, never an invented "preferred foreign
  /// currency": if home and living really are the same currency, both
  /// sides seed to that same value, preserving same-currency identity
  /// exactly as Task 14 requires.
  void _ensureSeeded(ProfileRow profile) {
    if (_seeded) return;
    _seeded = true;
    _fromCurrency =
        CurrencyRegistry.byCode(profile.homeCurrency) != null ? profile.homeCurrency : _currencyCodes.first;
    _toCurrency = CurrencyRegistry.byCode(profile.livingCurrency) != null
        ? profile.livingCurrency
        : _currencyCodes.first;
  }

  /// Task 7's explicit swap: reverses the From/To *selectors* only. This
  /// is NOT a mathematical inversion of any previously-resolved rate --
  /// swapping simply changes which ordered pair
  /// `referenceRateProvider((from, to))` is watching, so
  /// `ReferenceFxRateService` (via [_ConversionResult]) issues a genuinely
  /// new `to -> from` request (cache-checked, then provider-checked, on
  /// its own terms) the next time this widget builds. No `1 / rate`
  /// reciprocal is ever computed anywhere in this file.
  ///
  /// The typed amount is deliberately left untouched (Task 7's "preferred
  /// simple behavior") -- it is NOT replaced with the old converted
  /// result. [MoneyTextField] already re-validates its existing text
  /// against a newly-selected currency's own minor-unit precision via its
  /// own `didUpdateWidget` hook (see that widget's doc comment) whenever
  /// [_fromCurrency] changes, so the same number the user typed is simply
  /// reinterpreted as an amount in the new From currency -- exactly the
  /// same "keep the text, re-validate against the new currency" behavior
  /// every other currency-aware amount field in this app already has,
  /// with no special-casing added here.
  void _swap() {
    setState(() {
      final String from = _fromCurrency!;
      _fromCurrency = _toCurrency;
      _toCurrency = from;
    });
  }

  bool get _isFavorite {
    if (_fromCurrency == null || _toCurrency == null) return false;
    final List<(String, String)> favorites = ref.read(favoriteCurrencyPairsProvider);
    return favorites.contains((_fromCurrency!, _toCurrency!));
  }

  void _toggleFavorite(AppLocalizations l10n) {
    final String from = _fromCurrency!;
    final String to = _toCurrency!;
    final List<(String, String)> current = ref.read(favoriteCurrencyPairsProvider);
    final bool alreadyFavorite = current.contains((from, to));
    if (alreadyFavorite) {
      ref.read(favoriteCurrencyPairsProvider.notifier).state =
          current.where(((String, String) p) => p != (from, to)).toList();
      return;
    }
    if (current.length >= _favoritePairsLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.favoritePairsLimitReachedMessage(_favoritePairsLimit))),
      );
      return;
    }
    ref.read(favoriteCurrencyPairsProvider.notifier).state = <(String, String)>[
      ...current,
      (from, to),
    ];
  }

  void _selectFavorite((String, String) pair) {
    setState(() {
      _fromCurrency = pair.$1;
      _toCurrency = pair.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.currencyConverterTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text(l10n.couldNotLoadProfile('$e'))),
        data: (ProfileRow? profile) {
          if (profile == null) return const SizedBox.shrink();
          _ensureSeeded(profile);

          final String from = _fromCurrency!;
          final String to = _toCurrency!;
          final List<(String, String)> favorites = ref.watch(favoriteCurrencyPairsProvider);

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(l10n.currencyConverterFromLabel, style: context.appTypography.sectionTitle),
                const SizedBox(height: 8),
                _CurrencyDropdown(
                  key: const Key('fromCurrencyField'),
                  value: from,
                  onChanged: (String v) => setState(() => _fromCurrency = v),
                ),
                MoneyTextField(
                  key: const Key('converterAmountField'),
                  currencyCode: from,
                  label: l10n.currencyConverterAmountLabel,
                  onParsed: (Money? m) => setState(() => _amount = m),
                ),
                const SizedBox(height: 4),
                Center(
                  child: IconButton(
                    key: const Key('swapCurrenciesButton'),
                    tooltip: l10n.currencyConverterSwapTooltip,
                    icon: const Icon(Icons.swap_vert_rounded),
                    onPressed: _swap,
                  ),
                ),
                const SizedBox(height: 4),
                Text(l10n.currencyConverterToLabel, style: context.appTypography.sectionTitle),
                const SizedBox(height: 8),
                _CurrencyDropdown(
                  key: const Key('toCurrencyField'),
                  value: to,
                  onChanged: (String v) => setState(() => _toCurrency = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('toggleFavoritePairButton'),
                    tooltip: _isFavorite
                        ? l10n.removeFavoritePairTooltip
                        : l10n.addFavoritePairTooltip,
                    icon: Icon(_isFavorite ? Icons.star_rounded : Icons.star_border_rounded),
                    onPressed: () => _toggleFavorite(l10n),
                  ),
                ),
                const SizedBox(height: 12),
                _ConversionResult(fromCurrency: from, toCurrency: to, amount: _amount),
                const SizedBox(height: 24),
                _FavoritePairsSection(
                  favorites: favorites,
                  onSelect: _selectFavorite,
                  l10n: l10n,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A plain currency picker over [CurrencyRegistry.seed] -- Task 13.
/// Deliberately does not attempt
/// [InternationalPreferencesScreen]'s `_itemsPreservingCurrentValue`
/// unknown-value-preservation machinery: this screen always seeds From/To
/// from a value already guarded against an unrecognized code (see
/// [_CurrencyConverterScreenState._ensureSeeded]), and every subsequent
/// change only ever picks from this exact registry-backed item list, so
/// there is no "unknown persisted value" case to preserve here the way
/// there is for a profile field that can hold historical/legacy data.
class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static String _label(String code) {
    final Currency? currency = CurrencyRegistry.byCode(code);
    return currency == null ? code : '${currency.code} — ${currency.displayName}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        // CP5.3 precedent (see InternationalPreferencesScreen's identical
        // `_DropdownField`): `isExpanded: true` lets a long display name
        // ellipsize within the field's own width instead of forcing the
        // field wider than its surrounding layout allows.
        isExpanded: true,
        items: <DropdownMenuItem<String>>[
          for (final String code in _CurrencyConverterScreenState._currencyCodes)
            DropdownMenuItem<String>(
              value: code,
              child: Text(_label(code), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
            ),
        ],
        onChanged: (String? v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// The converted-result + Reference Rate status block (Tasks 5, 6, 8).
///
/// Same-currency (Task 6): performs a purely local identity conversion
/// via [FxConverter.convert] (never touches `rate`, never watches
/// `referenceRateProvider` at all -- no cache/provider/network call of
/// any kind) and shows a same-currency message instead of any Reference
/// Rate metadata.
///
/// Different currencies: watches `referenceRateProvider((fromCurrency,
/// toCurrency))` -- exactly the pair requested, never the inverse -- and
/// renders the fresh/stale/unavailable states using the exact same
/// [ReferenceRateView]/[ReferenceFxRateFormatter] presentation semantics
/// [ReferenceRateCard] already established in CP9.5, reusing its own
/// localization keys (Task 15) rather than re-deriving new copy for the
/// same concepts. An unavailable rate never invents a converted amount
/// (Task 8) -- the screen stays usable (currencies/amount remain
/// editable) even with no result to show.
class _ConversionResult extends ConsumerWidget {
  const _ConversionResult({required this.fromCurrency, required this.toCurrency, required this.amount});

  final String fromCurrency;
  final String toCurrency;
  final Money? amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (fromCurrency == toCurrency) {
      final Money? converted =
          amount == null ? null : FxConverter.convert(source: amount!, targetCurrencyCode: toCurrency);
      return AppCard(
        key: const Key('conversionResultCard'),
        bordered: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              converted == null
                  ? l10n.currencyConverterEnterAmountMessage
                  : l10n.approxAmountLabel(_formatter.format(converted)),
              key: const Key('convertedAmountText'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.currencyConverterSameCurrencyMessage, style: context.appTypography.secondaryBody),
          ],
        ),
      );
    }

    final AsyncValue<ReferenceRateResult> resultAsync =
        ref.watch(referenceRateProvider((fromCurrency, toCurrency)));

    return AppCard(
      key: const Key('conversionResultCard'),
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          resultAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            // A thrown exception is never rendered directly (mirrors
            // ReferenceRateCard's identical guard) -- reachable only by a
            // bug in ReferenceFxRateService itself, which otherwise
            // always reports failure through ReferenceRateUnavailable.
            error: (Object e, StackTrace st) => Text(
              l10n.referenceRateUnavailableMessage,
              key: const Key('conversionUnavailableMessage'),
              style: context.appTypography.secondaryBody,
            ),
            data: (ReferenceRateResult result) {
              final ReferenceRateView view = ReferenceRateView.from(
                result,
                baseCurrencyCode: fromCurrency,
                quoteCurrencyCode: toCurrency,
              );
              if (!view.hasUsableRate) {
                return Text(
                  l10n.referenceRateUnavailableMessage,
                  key: const Key('conversionUnavailableMessage'),
                  style: context.appTypography.secondaryBody,
                );
              }
              if (amount == null) {
                return Text(
                  l10n.currencyConverterEnterAmountMessage,
                  key: const Key('convertedAmountText'),
                  style: context.appTypography.secondaryBody,
                );
              }
              Money converted;
              try {
                converted = FxConverter.convert(
                  source: amount!,
                  targetCurrencyCode: toCurrency,
                  rate: view.rate,
                );
              } on MoneyOverflowException {
                return Text(
                  l10n.amountTooLargeMessage,
                  key: const Key('conversionOverflowMessage'),
                  style: context.appTypography.secondaryBody,
                );
              }
              final String formatted = _formatter.format(converted);
              final String label =
                  view.isStale ? l10n.approxAmountStaleLabel(formatted) : l10n.approxAmountLabel(formatted);
              return Text(
                label,
                key: const Key('convertedAmountText'),
                style: Theme.of(context).textTheme.headlineSmall,
              );
            },
          ),
          const SizedBox(height: 12),
          _ReferenceRateStatus(fromCurrency: fromCurrency, toCurrency: toCurrency),
        ],
      ),
    );
  }
}

/// The Reference Rate equation/source/updated/stale block -- reuses
/// exactly the same [ReferenceFxRateFormatter]-formatted equation text
/// and localization keys [ReferenceRateCard]'s `_ReferenceRateBody`
/// already established in CP9.5 (Task 8's "reuse CP9.5 presentation
/// semantics"), plus a manual-refresh affordance with the identical
/// Task G "simple V1 refresh" semantics: a plain `ref.invalidate` of this
/// exact pair, never a forced-network-refresh guarantee -- if
/// `ReferenceFxRateService`'s own freshness policy finds the cached entry
/// still fresh, invalidating re-runs this provider's callback but serves
/// straight from cache, exactly like CP9.5's Reference Rate card and Home
/// equivalent already do (see `reference_rate_provider_test.dart`'s
/// manual-refresh group for the same contract, proven there).
class _ReferenceRateStatus extends ConsumerWidget {
  const _ReferenceRateStatus({required this.fromCurrency, required this.toCurrency});

  final String fromCurrency;
  final String toCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ReferenceRateResult> resultAsync =
        ref.watch(referenceRateProvider((fromCurrency, toCurrency)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSectionHeader(
          icon: Icons.currency_exchange_rounded,
          title: l10n.referenceRateSectionTitle,
          eyebrow: true,
          trailing: IconButton(
            key: const Key('refreshConverterRateButton'),
            tooltip: l10n.referenceRateRefreshTooltip,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.invalidate(referenceRateProvider((fromCurrency, toCurrency))),
          ),
        ),
        const SizedBox(height: 4),
        resultAsync.maybeWhen(
          data: (ReferenceRateResult result) {
            final ReferenceRateView view = ReferenceRateView.from(
              result,
              baseCurrencyCode: fromCurrency,
              quoteCurrencyCode: toCurrency,
            );
            final String? formattedRate = view.formattedRate;
            if (!view.hasUsableRate || formattedRate == null) {
              return Text(
                l10n.referenceRateUnavailableMessage,
                style: context.appTypography.secondaryBody,
              );
            }
            final DateTime? fetchedAt = view.fetchedAt;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.referenceRateEquation(view.baseCurrencyCode, formattedRate, view.quoteCurrencyCode),
                  key: const Key('converterRateEquationText'),
                  style: context.appTypography.secondaryBody,
                ),
                const SizedBox(height: 4),
                Text(l10n.referenceRateExplanation, style: context.appTypography.secondaryBody),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (view.isStale)
                      AppStatusChip(
                        key: const Key('converterStaleChip'),
                        label: l10n.referenceRateStaleIndicator,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    if (view.source != null)
                      Text(
                        l10n.referenceRateSourceLabel(view.source!),
                        style: context.appTypography.secondaryBody,
                      ),
                    if (fetchedAt != null)
                      Text(
                        l10n.referenceRateUpdatedLabel(DateFormat.yMMMd().add_Hm().format(fetchedAt.toLocal())),
                        style: context.appTypography.secondaryBody,
                      ),
                  ],
                ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Task 11/12's favorite-pairs quick-access row. Listing favorites never
/// itself watches `referenceRateProvider` for any pair -- these are pure
/// data (`favoriteCurrencyPairsProvider`'s in-memory list), so opening
/// this screen with N saved favorites never fires N reference-rate
/// requests. Only the pair the user actually selects (which becomes
/// `_fromCurrency`/`_toCurrency`) is ever watched -- by
/// [_ConversionResult]/[_ReferenceRateStatus] above, exactly one pair at a
/// time.
class _FavoritePairsSection extends StatelessWidget {
  const _FavoritePairsSection({required this.favorites, required this.onSelect, required this.l10n});

  final List<(String, String)> favorites;
  final ValueChanged<(String, String)> onSelect;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.favoritePairsSectionTitle, style: context.appTypography.sectionTitle),
        const SizedBox(height: 4),
        Text(l10n.favoritePairsSessionNote, style: context.appTypography.caption),
        const SizedBox(height: 8),
        if (favorites.isEmpty)
          Text(
            l10n.noFavoritePairsMessage,
            key: const Key('noFavoritePairsMessage'),
            style: context.appTypography.secondaryBody,
          )
        else
          Wrap(
            key: const Key('favoritePairsList'),
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final (String, String) pair in favorites)
                ActionChip(
                  key: Key('favoritePair_${pair.$1}_${pair.$2}'),
                  label: Text('${pair.$1} → ${pair.$2}'),
                  onPressed: () => onSelect(pair),
                ),
            ],
          ),
      ],
    );
  }
}
