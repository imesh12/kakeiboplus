import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/providers.dart';
import '../database/repositories/drift_reference_fx_rate_cache.dart';
import '../network/http_transport.dart';
import 'exchangerate_api_fx_rate_provider.dart';
import 'fx_rate_provider.dart';
import 'in_memory_reference_fx_rate_cache.dart';
import 'reference_fx_rate_cache.dart';
import 'reference_fx_rate_service.dart';
import 'reference_rate_result.dart';

/// The app-lifetime reference-rate cache normal application code should
/// inject.
///
/// As of Checkpoint 9.3, this resolves to [DriftReferenceFxRateCache] --
/// persistent, backed by the `reference_exchange_rates` table (schema
/// v7) -- rather than CP9.2's original [InMemoryReferenceFxRateCache].
/// [InMemoryReferenceFxRateCache] is NOT deleted or deprecated: it
/// remains the right choice for focused unit tests, lightweight fakes,
/// and any context where a database isn't appropriate (see that class's
/// own doc) -- `referenceFxRateCacheProvider` is specifically about what
/// *normal running application code* gets when it asks Riverpod for a
/// [ReferenceFxRateCache].
///
/// Deliberately a plain `Provider` (not `.autoDispose`) -- same reasoning
/// as `appDatabaseProvider` in `lib/core/database/providers.dart`: a
/// cache that gets evicted the instant its last listener unsubscribes
/// would defeat the entire point of caching. Depending on
/// `appDatabaseProvider` (rather than constructing its own
/// `AppDatabase`) means this cache always shares the single
/// app-lifetime database connection every other repository provider in
/// `lib/core/database/providers.dart` already uses.
final Provider<ReferenceFxRateCache> referenceFxRateCacheProvider =
    Provider<ReferenceFxRateCache>(
  (ref) => DriftReferenceFxRateCache(ref.watch(appDatabaseProvider)),
);

/// The app-lifetime HTTP transport backing [fxRateProviderProvider].
///
/// A plain `Provider` returning a fresh, stateless [IoHttpTransport] --
/// constructing it performs no I/O of any kind (see [IoHttpTransport]'s
/// own doc); every actual network call happens lazily, only when
/// [ExchangeRateApiFxRateProvider.fetchRates] is actually invoked by
/// [ReferenceFxRateService]. Nothing about wiring this provider makes
/// app startup depend on the network (CP9.4 Task J).
final Provider<HttpTransport> httpTransportProvider =
    Provider<HttpTransport>((ref) => IoHttpTransport());

/// The app-lifetime [FxRateProvider] normal application code should
/// inject.
///
/// As of Checkpoint 9.4, this resolves to
/// [ExchangeRateApiFxRateProvider] -- CP9.2/CP9.3's abstraction finally
/// has a real, non-fake implementation. See that class's own doc for why
/// this vendor was selected and CP9.4's own report for the full
/// audit/selection rationale.
///
/// No configuration/API key exists for this provider (ExchangeRate-API's
/// "Open Access" endpoint requires none), so there is no
/// "configuration absent/invalid" case to special-case here -- unlike a
/// key-requiring vendor, this provider is always constructible. Wiring
/// it is still deliberately safe/lazy exactly as CP9.4 Task J requires:
/// constructing [ExchangeRateApiFxRateProvider] performs no network call
/// itself (only `fetchRates` does), so resolving this provider -- even
/// eagerly, even with no internet connectivity at all -- can never make
/// app startup fail or block.
final Provider<FxRateProvider> fxRateProviderProvider =
    Provider<FxRateProvider>(
  (ref) => ExchangeRateApiFxRateProvider(
    transport: ref.watch(httpTransportProvider),
  ),
);

/// The app-lifetime [ReferenceFxRateService] normal application code
/// should inject -- Checkpoint 9.5 Task B finally wires this. CP9.3/
/// CP9.4 deliberately left this unwired ("no UI consumer exists yet");
/// CP9.5 is that consumer (the Reference Rate settings card and the Home
/// dashboard's Home/Living equivalent -- see [referenceRateProvider]
/// below).
///
/// A plain `Provider` (not `.autoDispose`): the service object itself is
/// stateless glue over [fxRateProviderProvider]/[referenceFxRateCacheProvider]
/// (it owns no state of its own beyond those two collaborators) and
/// constructing it performs no I/O -- see [ReferenceFxRateService]'s own
/// constructor. Same "exactly one for the app's lifetime" reasoning as
/// `referenceFxRateCacheProvider` above.
final Provider<ReferenceFxRateService> referenceFxRateServiceProvider =
    Provider<ReferenceFxRateService>(
  (ref) => ReferenceFxRateService(
    provider: ref.watch(fxRateProviderProvider),
    cache: ref.watch(referenceFxRateCacheProvider),
  ),
);

/// Resolves the current reference rate for one specific, ordered
/// `(baseCurrencyCode, quoteCurrencyCode)` pair -- Checkpoint 9.5 Task
/// B's family/parameterized provider. The 2-tuple record key gives
/// natural value equality (Dart records compare structurally) with no
/// extra key class to define or maintain -- the same record-as-key
/// pattern `FxConverter._decompose` already uses for a different
/// purpose in this codebase.
///
/// # Direction is never inverted
///
/// The pair is always `(base, quote)` in the exact order the caller
/// means "1 base = ? quote" -- see [ReferenceFxRateService.referenceRate]
/// and [FxRate]'s own directional contract (imported transitively via
/// [ReferenceRateResult]). This provider does not (and must not) serve a
/// request for `(quote, base)` from an entry resolved for `(base,
/// quote)`, or vice versa -- a request for the inverse pair is a
/// genuinely different provider call (a different cache entry, a
/// different vendor query), never a client-side inversion of this one's
/// result. Every call site is responsible for requesting the pair in the
/// direction it actually needs, exactly as
/// `ReferenceFxRateService`/`FxConverter` already require of their own
/// callers.
///
/// `.autoDispose`: this provider's value is screen-scoped (the Reference
/// Rate settings card, and each Home dashboard currency card's
/// Home/Living equivalent line) -- unlike the app-lifetime service/cache
/// above, there is no reason to keep a specific pair's resolved future
/// alive once nothing on screen is asking for it. The underlying
/// [ReferenceFxRateService] still consults the persistent cache first on
/// the next request, so disposing and re-creating this provider never by
/// itself forces a new network call for a pair that's still within the
/// freshness window. No periodic/background refresh is started by this
/// provider -- re-evaluation only ever happens because a widget
/// (re)mounted and started watching it, or a caller explicitly
/// `ref.invalidate`s it (e.g. a manual "Refresh" affordance) -- Task G's
/// "simple V1 refresh" boundary.
final AutoDisposeFutureProviderFamily<ReferenceRateResult, (String, String)> referenceRateProvider =
    FutureProvider.autoDispose.family<ReferenceRateResult, (String, String)>(
  (ref, pair) {
    final ReferenceFxRateService service = ref.watch(referenceFxRateServiceProvider);
    return service.referenceRate(baseCurrencyCode: pair.$1, quoteCurrencyCode: pair.$2);
  },
);
