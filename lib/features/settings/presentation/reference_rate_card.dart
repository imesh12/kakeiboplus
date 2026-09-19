import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/fx/reference_fx_rate_providers.dart';
import '../../../core/fx/reference_rate_result.dart';
import '../../../core/fx/reference_rate_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_status_chip.dart';

/// Checkpoint 9.5 Task D: a small, read-only "Reference Rate" card for
/// International Preferences' Currency section, directly below the
/// home/living currency pickers it summarizes. Purely informational --
/// this never writes to the profile, never feeds a value back into any
/// accounting calculation, and never blocks that screen's own save flow
/// (a failed/unavailable/loading rate here has no effect on
/// [InternationalPreferencesScreen]'s own seeding/save behavior).
///
/// [homeCurrencyCode]/[livingCurrencyCode] are passed in from that
/// screen's own local, possibly-not-yet-saved dropdown selections
/// (`_homeCurrency`/`_livingCurrency`) rather than re-read from the
/// persisted profile -- so this card previews the pair the user is
/// currently looking at on screen, exactly like the two dropdowns right
/// above it, without this widget needing to know anything about that
/// screen's seeding/save mechanics itself.
///
/// # Direction
///
/// Always requested as `homeCurrencyCode -> livingCurrencyCode` (`"1
/// {home} = {rate} {living}"`) -- a deliberate, fixed product choice
/// (see `docs/14_DECISION_LOG.md` ADR-027): this screen already frames
/// both currencies from the same "home vs. living" perspective the rest
/// of the app uses, and a fixed direction means this card never needs
/// its own "which way round" control. Never queried in the inverse
/// direction from this screen.
///
/// # Same-currency (Task E)
///
/// When [homeCurrencyCode] equals [livingCurrencyCode], this makes NO
/// provider or cache call at all -- see the early return below, which
/// never even reads `referenceRateProvider`. There is nothing to convert
/// between a currency and itself, and CP9.5 Task E requires this to be
/// verifiable as zero network/provider calls, not merely a fast
/// identity path.
///
/// # Unrecognized currency codes never crash this card
///
/// [InternationalPreferencesScreen]'s own dropdowns deliberately tolerate
/// a persisted currency code [CurrencyRegistry] doesn't recognize (an
/// "Unknown (...)" synthetic item -- see that screen's own doc comment),
/// so [homeCurrencyCode]/[livingCurrencyCode] here are not guaranteed to
/// be known codes. `ReferenceFxRateService.referenceRate` calls
/// `CurrencyRegistry.require`, which throws `ArgumentError` for an
/// unknown code -- this widget checks [CurrencyRegistry.byCode] for both
/// codes FIRST and never calls `referenceRateProvider` at all when
/// either is unrecognized, showing the same unavailable message instead
/// of ever letting that exception reach this widget.
class ReferenceRateCard extends ConsumerWidget {
  const ReferenceRateCard({
    required this.homeCurrencyCode,
    required this.livingCurrencyCode,
    super.key,
  });

  final String homeCurrencyCode;
  final String livingCurrencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (homeCurrencyCode == livingCurrencyCode) {
      return AppCard(
        key: const Key('referenceRateCard'),
        bordered: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionHeader(
              icon: Icons.currency_exchange_rounded,
              title: l10n.referenceRateSectionTitle,
              eyebrow: true,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.referenceRateSameCurrencyMessage,
              style: context.appTypography.secondaryBody,
            ),
          ],
        ),
      );
    }

    final bool bothCurrenciesKnown = CurrencyRegistry.byCode(homeCurrencyCode) != null &&
        CurrencyRegistry.byCode(livingCurrencyCode) != null;

    final AsyncValue<ReferenceRateResult>? resultAsync = bothCurrenciesKnown
        ? ref.watch(referenceRateProvider((homeCurrencyCode, livingCurrencyCode)))
        : null;

    return AppCard(
      key: const Key('referenceRateCard'),
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            icon: Icons.currency_exchange_rounded,
            title: l10n.referenceRateSectionTitle,
            eyebrow: true,
            trailing: IconButton(
              key: const Key('refreshReferenceRateButton'),
              tooltip: l10n.referenceRateRefreshTooltip,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              // Task G's "simple V1 refresh": a plain Riverpod
              // invalidation of this exact pair -- no retry queue, no
              // background/periodic timer. The underlying service still
              // consults the persistent cache first, so this only ever
              // triggers a network call when the cached entry (if any)
              // is actually stale. Disabled outright (rather than a
              // no-op) when either currency code isn't recognized --
              // there is no provider result here to refresh.
              onPressed: bothCurrenciesKnown
                  ? () => ref
                      .invalidate(referenceRateProvider((homeCurrencyCode, livingCurrencyCode)))
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          if (resultAsync == null)
            Text(
              l10n.referenceRateUnavailableMessage,
              key: const Key('referenceRateUnavailableMessage'),
              style: context.appTypography.secondaryBody,
            )
          else
            resultAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              // A thrown exception is never rendered directly (Task H)
              // -- this branch can only be reached by a bug in
              // ReferenceFxRateService itself (it reports every
              // provider failure through ReferenceRateUnavailable
              // rather than throwing), but stays a safe, generic
              // message rather than ever surfacing `e`.
              error: (Object e, StackTrace st) => Text(
                l10n.referenceRateUnavailableMessage,
                key: const Key('referenceRateUnavailableMessage'),
                style: context.appTypography.secondaryBody,
              ),
              data: (ReferenceRateResult result) {
                final ReferenceRateView view = ReferenceRateView.from(
                  result,
                  baseCurrencyCode: homeCurrencyCode,
                  quoteCurrencyCode: livingCurrencyCode,
                );
                return _ReferenceRateBody(view: view, l10n: l10n);
              },
            ),
        ],
      ),
    );
  }
}

/// The fresh/stale/unavailable contents of [ReferenceRateCard] once a
/// result has actually resolved. [view.isIdentity] is never expected
/// here (the card's same-currency branch returns before ever building
/// this), so it is treated the same as unavailable rather than crashing,
/// purely as defensive belt-and-braces.
class _ReferenceRateBody extends StatelessWidget {
  const _ReferenceRateBody({required this.view, required this.l10n});

  final ReferenceRateView view;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? formattedRate = view.formattedRate;

    if (!view.hasUsableRate || formattedRate == null) {
      return Text(
        l10n.referenceRateUnavailableMessage,
        key: const Key('referenceRateUnavailableMessage'),
        style: context.appTypography.secondaryBody,
      );
    }

    final String equation = l10n.referenceRateEquation(
      view.baseCurrencyCode,
      formattedRate,
      view.quoteCurrencyCode,
    );
    final DateTime? fetchedAt = view.fetchedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          equation,
          key: const Key('referenceRateEquationText'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.referenceRateExplanation,
          style: context.appTypography.secondaryBody,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            // Task J: stale is a neutral status, never colored as a
            // warning/error -- `onSurfaceVariant`, the same neutral tone
            // every other muted caption on this screen already uses.
            if (view.isStale)
              AppStatusChip(
                key: const Key('referenceRateStaleChip'),
                label: l10n.referenceRateStaleIndicator,
                color: colors.onSurfaceVariant,
              ),
            if (view.source != null)
              Text(
                l10n.referenceRateSourceLabel(view.source!),
                style: context.appTypography.secondaryBody,
              ),
            if (fetchedAt != null)
              Text(
                l10n.referenceRateUpdatedLabel(
                  DateFormat.yMMMd().add_Hm().format(fetchedAt.toLocal()),
                ),
                style: context.appTypography.secondaryBody,
              ),
          ],
        ),
      ],
    );
  }
}
