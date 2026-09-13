import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/providers.dart';
import '../core/locale/app_locale_provider.dart';
import '../core/routing/app_router.dart';
import '../features/recurring/presentation/recurring_notification_providers.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/theme/app_theme.dart';
import '../shared/theme/app_theme_provider.dart';
import '../shared/theme/app_theme_style.dart';

/// App root: wires up `MaterialApp.router` with the Beta 0 [GoRouter],
/// seeds system categories once the database is available, (Beta 1
/// Task 4B) reconciles recurring reminder notifications, and
/// (International / Localization Foundation Checkpoint 4.2) resolves the
/// app's runtime [Locale] from [appLocaleProvider] -- a pure derivation
/// of the persisted profile's language, never a write path (see that
/// provider's own doc comment). CP4.2 wires the locale/delegates only;
/// no production widget strings are localized yet, and Japanese is not
/// yet selectable anywhere in the UI.
///
/// Checkpoint 8.1 (Premium Theme Personalization Foundation) resolves
/// the app's active [ThemeData] from [appThemeStyleProvider] the exact
/// same way -- a pure derivation of the persisted profile's
/// `theme_preference`, never a write path (see that provider's own doc
/// comment). `theme:` is now `AppTheme.resolve(ref.watch
/// (appThemeStyleProvider))` instead of the previous hard-coded
/// `AppTheme.light()`, and `themeMode: ThemeMode.light` is set
/// explicitly (new -- previously unset, which defaulted to
/// `ThemeMode.system`) so Flutter's own automatic OS-brightness-driven
/// switch away from `theme:` never overrides the user's explicit 5-way
/// theme choice -- including when the user has explicitly chosen
/// [AppThemeStyle.dark] itself, which must not then also be silently
/// swapped out again by the OS switching brightness. The previous
/// `darkTheme: AppTheme.dark()` parameter is removed: with `themeMode`
/// pinned to [ThemeMode.light], `MaterialApp` never consults
/// `darkTheme` for any reason, so leaving it wired would be dead,
/// misleading code -- [AppThemeStyle.dark] reaches users exclusively
/// through `theme:` now, via [AppTheme.resolve].
///
/// A [ConsumerStatefulWidget] rather than the simpler [ConsumerWidget]
/// specifically so it can be a [WidgetsBindingObserver] -- Task 4B
/// correction 2 requires reconciling on app foreground/resume (in
/// addition to cold start and rule/occurrence data changes, which
/// [recurringNotificationReconcilerProvider] already reacts to on its
/// own via Riverpod), and `didChangeAppLifecycleState` is the standard
/// Flutter hook for that without a background worker/isolate -- Beta 1
/// deliberately has neither (same correction). No other behavior here
/// changes; this is the minimal shape needed for that one hook.
class AiFinancialCoachApp extends ConsumerStatefulWidget {
  const AiFinancialCoachApp({super.key});

  @override
  ConsumerState<AiFinancialCoachApp> createState() => _AiFinancialCoachAppState();
}

class _AiFinancialCoachAppState extends ConsumerState<AiFinancialCoachApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Invalidating forces recurringNotificationReconcilerProvider's
      // body to re-run against a fresh `DateTime.now()` even when
      // nothing about the rules/occurrences themselves changed while
      // backgrounded -- see that provider's doc comment.
      ref.invalidate(recurringNotificationReconcilerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fire-and-forget: idempotent (insertOrIgnore — see
    // CategoryRepository.seedSystemCategoriesIfNeeded), safe to call on
    // every app start.
    unawaited(ref.watch(categoryRepositoryProvider).seedSystemCategoriesIfNeeded());

    // Instantiates (once) and keeps alive the Beta 1 Task 4B recurring
    // reminder reconciler -- see that provider's doc comment for why a
    // single `ref.watch` here is enough for it to keep reacting to
    // rule/occurrence changes for the rest of the app's lifetime.
    ref.watch(recurringNotificationReconcilerProvider);

    final GoRouter router = ref.watch(routerProvider);

    // CP4.2: derived purely from the persisted profile (see
    // appLocaleProvider's doc comment) -- never written back, never
    // mutates the profile. No screen consumes AppLocalizations yet; this
    // only makes MaterialApp resolve/accept the two supported locales.
    final Locale locale = ref.watch(appLocaleProvider);

    // Checkpoint 8.1: derived purely from the persisted profile (see
    // appThemeStyleProvider's doc comment) -- never written back, never
    // mutates the profile. Any write elsewhere (the Theme Customization
    // screen) causes this to recompute automatically via
    // activeProfileProvider's live Drift stream, so a theme change
    // applies instantly, with no restart and no manual notification.
    final AppThemeStyle themeStyle = ref.watch(appThemeStyleProvider);

    return MaterialApp.router(
      title: 'AI Financial Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.resolve(themeStyle),
      themeMode: ThemeMode.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
