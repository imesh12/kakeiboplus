import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/providers.dart';
import '../database/repositories/drift_reference_fx_rate_cache.dart';
import '../network/http_transport.dart';
import 'exchangerate_api_fx_rate_provider.dart';
import 'fx_rate_provider.dart';
import 'in_memory_reference_fx_rate_cache.dart';
import 'reference_fx_rate_cache.dart';

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

// A `ReferenceFxRateService` DI provider is deliberately still NOT
// defined here, even though CP9.4 finally gives it a real
// [FxRateProvider] to pair with the persistent cache above. CP9.3's own
// reasoning here is unchanged by CP9.4:
//   - no UI screen or widget consumes a reference rate yet (see CP9.4's
//     explicit "Do NOT add FX UI yet" prohibition -- unchanged from
//     CP9.2/CP9.3), and
//   - CP9.4 is explicitly network/provider infrastructure only -- it
//     does not start automatic/background refresh, and does not add a
//     consumer to exercise a service provider.
// Wiring a service provider with no consumer to serve would be exactly
// the "UI-facing complexity without a consumer" CP9.2's audit already
// warned against, and neither CP9.3 nor CP9.4 changes that calculus.
// `ReferenceFxRateService` remains directly constructible (see its own
// constructor) -- trivial to wire once a real consumer exists -- from
// `fxRateProviderProvider` and `referenceFxRateCacheProvider` above.
