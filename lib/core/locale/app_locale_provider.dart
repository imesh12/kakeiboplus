import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/presentation/profile_providers.dart';
import '../database/app_database.dart';
import 'app_language.dart';

/// International / Localization Foundation Checkpoint 4.2: derives the
/// app's runtime [Locale] from the persisted profile's
/// `preferred_language`, and nothing else.
///
/// # Purity -- why this provider never writes anything
///
/// This only ever READS [activeProfileProvider]. It must never call
/// `ProfileRepository.updateInternationalPreferences` (or any other
/// write method), never rewrite an unknown/legacy persisted language
/// value back to `'en'`, and never trigger an onboarding write --
/// opening/running the app must never mutate the profile. An
/// unrecognized persisted value falls back to English for the runtime
/// `Locale` only; the raw stored string is left completely untouched,
/// exactly the same raw-value-is-source-of-truth policy
/// `InternationalPreferencesScreen` already applies to its own dropdowns
/// (see that file's class doc comment) -- CP4.2 just applies it one
/// layer up, at locale resolution instead of UI labels.
///
/// Deterministic mapping (every branch below collapses to one of two
/// outcomes -- there is no third path):
///  - `preferredLanguage == 'ja'`                     -> `Locale('ja')`
///  - `preferredLanguage == 'en'`                     -> `Locale('en')`
///  - unknown/corrupt persisted value                 -> `Locale('en')`
///    (runtime fallback only -- storage is untouched)
///  - profile still loading (`AsyncLoading`)           -> `Locale('en')`
///  - no profile yet (`AsyncData(null)`, pre-onboarding) -> `Locale('en')`
///  - profile stream errored (`AsyncError`)             -> `Locale('en')`
///
/// [AsyncValue.valueOrNull] is what collapses loading/error/no-profile
/// into the same safe fallback without an explicit `.when(...)`: it is
/// `null` in every one of those states (there is no previously-cached
/// value to fall back to on a fresh read), and `null?.preferredLanguage`
/// short-circuits to `null`, which never equals `'ja'` -- so every
/// non-Japanese-selected case, including all the fallback ones, falls
/// through to the same single `Locale('en')` return with no branching
/// needed for each case individually.
///
/// A plain [Provider] (not a [StreamProvider]/[Notifier]/[AsyncNotifier])
/// is deliberate: [activeProfileProvider] is already the async source of
/// truth this derives from, so [appLocaleProvider] only needs to
/// synchronously compute a [Locale] from its current [AsyncValue] --
/// no async state of its own to manage, and no write path to expose.
final Provider<Locale> appLocaleProvider = Provider<Locale>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final String? preferredLanguage = profileAsync.valueOrNull?.preferredLanguage;

  if (preferredLanguage == AppLanguageRegistry.japanese.code) {
    return const Locale('ja');
  }
  return const Locale('en');
});
