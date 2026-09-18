import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/providers.dart';
import '../database/repositories/drift_reference_fx_rate_cache.dart';
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

// A `ReferenceFxRateService` (and `FxRateProvider`) DI provider is
// deliberately still NOT defined here. Nothing about CP9.3 changes this:
//   - no real `FxRateProvider` implementation exists to inject (a real
//     vendor integration is explicitly out of scope -- see this
//     checkpoint's "No Real Network" prohibition), and
//   - no UI screen or widget consumes a reference rate (see this
//     checkpoint's "No FX UI" prohibition), and
//   - CP9.3 is explicitly database-only infrastructure -- it does not
//     start automatic/background refresh either.
// Wiring a service provider with no real dependency to inject and no
// consumer to serve would be exactly the "UI-facing complexity without a
// consumer" CP9.2's audit already warned against, and CP9.3 doesn't
// change that calculus. `ReferenceFxRateService` remains directly
// constructible (see its own constructor) for the checkpoint that adds a
// real provider and/or a consuming screen.
