import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/locale/app_locale_provider.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// International / Localization Foundation Checkpoint 4.2: a minimal
// probe proving the exact MaterialApp wiring lib/app/app.dart uses --
// `locale: ref.watch(appLocaleProvider)` together with
// `AppLocalizations.localizationsDelegates` /
// `AppLocalizations.supportedLocales` -- actually resolves
// `Localizations.localeOf(context)` to the provider-derived locale and
// exposes a working `AppLocalizations.of(context)`, for both supported
// locales. Deliberately does NOT pump the real `AiFinancialCoachApp`
// (that would drag in GoRouter, category seeding, and the recurring
// notification reconciler -- unrelated surface for a CP4.2 wiring
// proof) and does NOT localize any production widget -- the probe
// widget below exists only in this test file.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;

  tearDown(() async {
    await db.close();
  });

  Future<String> seedProfile({required String preferredLanguage}) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    return profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: 'LKR',
      livingCurrency: 'JPY',
      preferredLanguage: preferredLanguage,
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
  }

  /// The same three `MaterialApp` parameters `lib/app/app.dart` wires,
  /// around a bare probe [Text] instead of the real router/shell --
  /// `Localizations.localeOf`/`AppLocalizations.of` care about the
  /// `MaterialApp` ancestor, not what's below it.
  Widget probeApp(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final Locale locale = ref.watch(appLocaleProvider);
          return MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (BuildContext context) {
                // Touching AppLocalizations.of(context) proves the
                // delegate actually resolved for this locale -- it
                // throws if Localizations can't find an AppLocalizations
                // instance in the tree for the active locale.
                final String probe = AppLocalizations.of(context).save;
                return Text('locale=${Localizations.localeOf(context)} probe=$probe');
              },
            ),
          );
        },
      ),
    );
  }

  testWidgets(
      'an English-language profile resolves Localizations.localeOf to en and '
      'AppLocalizations.of does not throw', (tester) async {
    await seedProfile(preferredLanguage: 'en');
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(probeApp(container));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Text));
    expect(Localizations.localeOf(context), const Locale('en'));
    expect(find.textContaining('probe=Save'), findsOneWidget);
  });

  testWidgets(
      'a Japanese-language profile resolves Localizations.localeOf to ja, '
      'AppLocalizations.of does not throw, and ja is an accepted supportedLocale',
      (tester) async {
    await seedProfile(preferredLanguage: 'ja');
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(probeApp(container));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Text));
    expect(Localizations.localeOf(context), const Locale('ja'));
    expect(find.textContaining('probe=保存'), findsOneWidget);
  });
}
