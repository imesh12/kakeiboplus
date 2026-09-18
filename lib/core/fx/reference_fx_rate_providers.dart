import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'in_memory_reference_fx_rate_cache.dart';
import 'reference_fx_rate_cache.dart';

/// The app-lifetime in-memory reference-rate cache.
///
/// Deliberately a plain `Provider` (not `.autoDispose`) -- same reasoning
/// as `appDatabaseProvider` in `lib/core/database/providers.dart`: a
/// cache that gets evicted the instant its last listener unsubscribes
/// would defeat the entire point of caching.
///
/// This cache is in-memory only and does NOT survive process restart --
/// see [InMemoryReferenceFxRateCache]'s class doc and the CP9.2 report's
/// "CACHE" / "DEFERRED CP9.x WORK" sections for why a durable cache is
/// out of scope for this checkpoint (it would require a new Drift
/// migration).
final Provider<ReferenceFxRateCache> referenceFxRateCacheProvider =
    Provider<ReferenceFxRateCache>((ref) => InMemoryReferenceFxRateCache());

// A `ReferenceFxRateService` (and `FxRateProvider`) DI provider is
// deliberately NOT defined here yet. CP9.2 has:
//   - no real `FxRateProvider` implementation to inject (a real vendor
//     integration is explicitly out of scope -- see the checkpoint's
//     "No Real Network" prohibition), and
//   - no UI screen or widget that consumes a reference rate (see the
//     checkpoint's "No FX UI" prohibition).
// Wiring a provider for a service with no real dependency to inject and
// no consumer to serve would be exactly the "UI-facing complexity
// without a consumer" this checkpoint's audit explicitly warns against.
// `ReferenceFxRateService` remains directly constructible (see its own
// constructor) for the checkpoint that adds a real provider and/or a
// consuming screen to wire this up properly.
