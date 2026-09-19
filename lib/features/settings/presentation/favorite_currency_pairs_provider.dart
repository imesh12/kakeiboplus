import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Checkpoint 9.6 Task 11/12: the user's favorite Currency Converter
/// pairs -- e.g. `(LKR, JPY)`.
///
/// # Persistence decision -- SESSION-ONLY, deliberately, for V1
///
/// CP9.6's audit found no schema migration- or new-dependency-free way to
/// persist this durably: the `profiles` table has no generic key-value/JSON
/// column to (ab)use, there is no `shared_preferences` (or equivalent)
/// dependency anywhere in `pubspec.yaml` today, and CP9.6's own explicit
/// "Favorite Persistence Safety" boundary forbids adding either a casual
/// database column or a new dependency "merely for this feature." A
/// durable favorites table (schema v7 -> v8) or a new preferences
/// dependency are both real, available options for a future checkpoint,
/// but neither is "safe/low-risk" enough to bundle into CP9.6's batch --
/// see `docs/14_DECISION_LOG.md` ADR-028 for the full reasoning.
///
/// This provider is therefore a plain in-memory `StateProvider`: favorites
/// live only as long as this `ProviderContainer` (i.e. the app process).
/// They do NOT survive an app restart, and nothing about this provider
/// pretends otherwise -- [CurrencyConverterScreen] surfaces this
/// explicitly via `favoritePairsSessionNote` rather than silently letting
/// the user believe a starred pair is durably saved.
///
/// # Ordered-pair semantics
///
/// Each entry is a `(String base, String quote)` record -- the exact same
/// "record as an ordered-pair key" idiom `referenceRateProvider`
/// (`lib/core/fx/reference_fx_rate_providers.dart`) already uses.
/// `(LKR, JPY)` and `(JPY, LKR)` are two distinct favorites; this provider
/// never merges, reorders, or deduplicates a pair with its reverse.
///
/// # No cap enforcement here
///
/// The V1 cap (6 pairs -- Task 12) is enforced by the screen, not this
/// provider, so the provider itself stays a trivial, cap-agnostic list.
/// This provider never fetches anything over the network by itself --
/// listing/toggling a favorite is pure local state; only the SELECTED
/// pair ever becomes a `referenceRateProvider` watch (see
/// `CurrencyConverterScreen`).
final StateProvider<List<(String, String)>> favoriteCurrencyPairsProvider =
    StateProvider<List<(String, String)>>((ref) => const <(String, String)>[]);
