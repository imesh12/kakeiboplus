import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/onboarding/presentation/profile_providers.dart';
import 'app_theme_style.dart';

/// Checkpoint 8.1 (Premium Theme Personalization Foundation): derives the
/// app's active [AppThemeStyle] from the persisted profile's
/// `theme_preference`, and nothing else -- modeled directly on
/// `lib/core/locale/app_locale_provider.dart`'s `appLocaleProvider`
/// (same shape, same purity guarantee, same fallback strategy).
///
/// # Purity -- why this provider never writes anything
///
/// This only ever READS [activeProfileProvider]. It must never call
/// `ProfileRepository.updateThemePreference` (or any other write
/// method), never rewrite an unknown/legacy persisted value back to
/// `'light'`, and never trigger a write as a side effect of being
/// watched -- opening the app, or navigating to any screen, must never
/// mutate the profile merely by reading its theme. An unrecognized
/// persisted value falls back to [AppThemeStyle.fallback] for the
/// runtime [AppThemeStyle] only; the raw stored string is left
/// completely untouched -- see [AppThemeStyle.fromStorageValue]'s own
/// doc comment for the same policy `appLocaleProvider` already applies
/// to `preferredLanguage`.
///
/// Deterministic mapping (every branch collapses to one of two
/// outcomes -- there is no third path):
///  - a recognized persisted value ('light'/'dark'/'pink'/'ocean'/
///    'forest') -> that [AppThemeStyle]
///  - unknown/corrupt persisted value          -> [AppThemeStyle.fallback]
///    (runtime fallback only -- storage is untouched)
///  - profile still loading (`AsyncLoading`)    -> [AppThemeStyle.fallback]
///  - no profile yet (`AsyncData(null)`, pre-onboarding) -> [AppThemeStyle.fallback]
///  - profile stream errored (`AsyncError`)      -> [AppThemeStyle.fallback]
///
/// [AsyncValue.valueOrNull] collapses loading/error/no-profile into the
/// same safe fallback without an explicit `.when(...)`, exactly as
/// `appLocaleProvider` already does: it is `null` in every one of those
/// states, and `null?.themePreference` short-circuits to `null`, which
/// [AppThemeStyle.fromStorageValue] already treats as "use fallback" --
/// so every non-recognized case, fallback ones included, resolves
/// through the exact same single code path with no branching needed for
/// each case individually.
///
/// A plain [Provider] (not a [StreamProvider]/[Notifier]/[AsyncNotifier])
/// is deliberate, for the same reason `appLocaleProvider` is one:
/// [activeProfileProvider] is already the async source of truth this
/// derives from, so [appThemeStyleProvider] only needs to synchronously
/// compute an [AppThemeStyle] from its current [AsyncValue] -- no async
/// state of its own to manage, and no write path to expose. Because
/// [activeProfileProvider] is a live Drift [Stream] (see
/// `profile_providers.dart`), any write elsewhere (e.g. the Theme
/// Customization screen calling `updateThemePreference`) causes this
/// provider to recompute automatically and every `ref.watch` of it to
/// rebuild -- the mechanism that makes theme switching instant and
/// restart-free without any manual state-notification plumbing.
final Provider<AppThemeStyle> appThemeStyleProvider = Provider<AppThemeStyle>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final String? themePreference = profileAsync.valueOrNull?.themePreference;
  return AppThemeStyle.fromStorageValue(themePreference);
});
