import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/settings/presentation/international_preferences_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/more_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// International / Localization Foundation Checkpoint 3B. Uses a real
// (minimal) `GoRouter` -- same pattern as
// `test/widget/transaction_detail_screen_test.dart`'s `appWithRouter` --
// since the screen navigates via `context.push`/`context.pop`.
//
// # Widget-test interaction helpers -- why they look like this
//
// Three focused real runs against earlier versions of this file exposed
// structural problems with naive `DropdownButtonFormField` interaction
// in a *scrollable* screen (see the fix-requests that produced this
// revision):
//
//  1. Lower fields and the Save button can be genuinely off-screen in
//     the test surface's viewport, AND a field further up can become
//     off-screen again after scrolling down for a later field --
//     `find.byKey`/`find.text` on an unbuilt-because-off-screen widget
//     fails, not just `tester.tap`. `scrollPageUntilVisible` (used by
//     both `ensureFieldVisible` and `save`) never calls
//     `tester.ensureVisible` against a finder that currently evaluates
//     to zero elements: if the target isn't already present, it first
//     resets the primary `Scrollable`'s position to the very top -- a
//     target scrolled PAST can never be found by a helper that only
//     ever searches in one direction -- then searches downward from
//     there in small bounded increments until the target appears, THEN
//     calls `tester.ensureVisible` on it.
//  2. Selecting a popup option is done by its hit-testable DISPLAY TEXT
//     after the field's own `DropdownButtonFormField<String>` descendant
//     (not the outer keyed wrapper) has been tapped open -- never by
//     `find.text(label).last` (which can match a retained,
//     non-interactive copy in a DIFFERENT closed dropdown's internal
//     `IndexedStack`), and never by matching a `DropdownMenuItem<String>`
//     widget directly: that type is only what the CLOSED button's
//     `IndexedStack` literally contains -- the OPEN popup route builds
//     its options from a different widget wrapping each item's `child`,
//     so a `DropdownMenuItem<String>` predicate matches zero hit-testable
//     widgets once the menu is actually open. The popup menu also has
//     its OWN internal `Scrollable`, separate from the page's -- when a
//     label exists in the tree but isn't yet hit-testable,
//     `visiblePopupOption` identifies that new popup `Scrollable`
//     (whichever one appeared since the menu opened -- never `.last`,
//     which would only be a guess about tree/paint order) and scrolls
//     bounded increments on THAT scrollable, never the page's. Every
//     call asserts exactly one hit-testable match for the expected
//     label before tapping it, then re-reads the field's own live value
//     to confirm the interaction actually landed (see point 3) rather
//     than trusting the tap alone.
//  3. Reading a dropdown's CURRENT value is done via the keyed field's
//     own `FormFieldState<String>.value` (`DropdownButtonFormField`
//     extends `FormField`), not by hunting for an internal
//     `DropdownButton<String>` descendant and never via `.items` (which
//     `DropdownButtonFormField<String>` does not expose as a public
//     getter in this Flutter version) -- `DropdownButtonFormField`'s
//     `initialValue` is a one-time seed, not a live reflection of
//     selection, so `FormFieldState.value` is the only value that's
//     actually current after an interaction.
void main() {
  Future<(AppDatabase, String profileId)> seededDb({
    String homeCountry = 'LK',
    String currentCountry = 'JP',
    String homeCurrency = 'LKR',
    String livingCurrency = 'JPY',
    String preferredLanguage = 'en',
    String timezone = 'Asia/Tokyo',
    String dateFormat = 'yyyy-MM-dd', // legacy raw value, on purpose (matches historical onboarding output)
    String numberFormat = '#,##0.##', // legacy raw value, on purpose
  }) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: homeCountry,
      currentCountry: currentCountry,
      homeCurrency: homeCurrency,
      livingCurrency: livingCurrency,
      preferredLanguage: preferredLanguage,
      timezone: timezone,
      dateFormat: dateFormat,
      numberFormat: numberFormat,
    );
    return (db, profileId);
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  Widget appWithRouter(
    ProviderContainer container, {
    bool startAtMore = false,
    Locale locale = const Locale('en'),
  }) {
    final GoRouter router = GoRouter(
      initialLocation: startAtMore ? AppRoutes.more : '/launcher',
      routes: <RouteBase>[
        GoRoute(
          path: '/launcher',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.internationalPreferences),
                child: const Text('open international preferences'),
              ),
            ),
          ),
        ),
        GoRoute(path: AppRoutes.more, builder: (context, state) => const MoreScreen()),
        GoRoute(
          path: AppRoutes.internationalPreferences,
          builder: (context, state) => const InternationalPreferencesScreen(),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> openScreen(
    WidgetTester tester,
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(appWithRouter(container, locale: locale));
    await tester.tap(find.text('open international preferences'));
    await tester.pumpAndSettle();
  }

  /// Deterministically brings [target] into view within the screen's
  /// primary `Scrollable`. If [target] is already present in the tree,
  /// this is just `tester.ensureVisible`. Otherwise it resets scroll
  /// position to the very TOP first -- a target scrolled PAST (e.g. a
  /// top field, right after a lower field was interacted with) can never
  /// be found by a helper that only ever searches in one direction --
  /// then searches downward from there in small bounded increments,
  /// pumping after each drag, until [target] appears. Never calls
  /// `tester.ensureVisible` against a finder that currently evaluates to
  /// zero elements. See file-level doc comment, point 1.
  Future<void> scrollPageUntilVisible(WidgetTester tester, Finder target, {required String description}) async {
    if (target.evaluate().isEmpty) {
      final Finder scrollable = find.byType(Scrollable).first;
      final ScrollableState scrollableState = tester.state<ScrollableState>(scrollable);
      if (scrollableState.position.pixels != 0) {
        scrollableState.position.jumpTo(0);
        await tester.pump();
      }

      const int maxScrollAttempts = 20;
      int attempts = 0;
      while (target.evaluate().isEmpty && attempts < maxScrollAttempts) {
        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pump();
        attempts++;
      }
      if (target.evaluate().isEmpty) {
        fail(
          '$description was not found after resetting the page to the top and '
          '$maxScrollAttempts bounded scroll attempts.',
        );
      }
    }

    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  /// Scrolls [key]'s field into view within the screen's scrollable body.
  /// Every other helper below calls this before touching a keyed field --
  /// see the file-level doc comment, point 1.
  Future<void> ensureFieldVisible(WidgetTester tester, Key key) async {
    await scrollPageUntilVisible(tester, find.byKey(key), description: 'Field with key $key');
  }

  /// The keyed field's own live `FormFieldState<String>.value` --
  /// `DropdownButtonFormField<String>` is a `FormField<String>`, and this
  /// is its actual current selection (unlike `initialValue`, which is
  /// only the one-time seed). See file-level doc comment, point 3.
  Future<String?> fieldValue(WidgetTester tester, Key key) async {
    await ensureFieldVisible(tester, key);
    final FormFieldState<String> state = tester.state<FormFieldState<String>>(
      find.descendant(of: find.byKey(key), matching: find.byType(DropdownButtonFormField<String>)),
    );
    return state.value;
  }

  /// After a dropdown's popup menu has just been opened, returns a
  /// finder for [label]'s hit-testable popup option -- scrolling the
  /// POPUP's own internal `Scrollable` (never the page's, and never by
  /// guessing `.last`) in small bounded increments first if [label]
  /// isn't immediately hit-testable. See file-level doc comment, point
  /// 2. [scrollablesBeforeOpen] must be captured (`find.byType(Scrollable)
  /// .evaluate().toSet()`) immediately before the menu-opening tap, so
  /// the newly-added popup `Scrollable` can be identified by set
  /// difference rather than by assumed tree/paint order. Fails loudly if
  /// the resulting match count isn't exactly 1.
  Future<Finder> visiblePopupOption(
    WidgetTester tester, {
    required Set<Element> scrollablesBeforeOpen,
    required String label,
  }) async {
    Finder option = find.text(label).hitTestable();

    if (option.evaluate().isEmpty) {
      final List<Element> newScrollables = find
          .byType(Scrollable)
          .evaluate()
          .where((Element e) => !scrollablesBeforeOpen.contains(e))
          .toList();
      expect(
        newScrollables,
        hasLength(1),
        reason: 'Expected exactly 1 new Scrollable (the popup menu) since it opened, '
            'found ${newScrollables.length}. Investigate rather than assume.',
      );
      final Finder popupScrollable = find.byElementPredicate((Element e) => e == newScrollables.single);

      const int maxScrollAttempts = 20;
      int attempts = 0;
      while (option.evaluate().isEmpty && attempts < maxScrollAttempts) {
        await tester.drag(popupScrollable, const Offset(0, -100));
        await tester.pump();
        attempts++;
        option = find.text(label).hitTestable();
      }
    }

    final int count = option.evaluate().length;
    expect(
      count,
      1,
      reason: 'Expected exactly 1 hit-testable "$label" popup option (scrolling the popup menu '
          'if needed), found $count. Investigate rather than assume -- this may mean the popup '
          'route did not open, the label text does not match production exactly, or more than '
          'one hit-testable match is visible at once.',
    );
    return option;
  }

  /// Opens [key]'s dropdown -- by tapping the actual
  /// `DropdownButtonFormField<String>` descendant, not the outer keyed
  /// wrapper -- and selects the option whose visible display text is
  /// [itemLabel] (via [visiblePopupOption]), then asserts the field's
  /// live `FormFieldState<String>.value` is now [itemValue]. See
  /// file-level doc comment, point 2, for why selection is by
  /// hit-testable display TEXT rather than by inspecting
  /// `DropdownMenuItem<String>` widget configuration (which the open
  /// popup route does not use directly, and which
  /// `DropdownButtonFormField<String>` exposes no public `items` getter
  /// to read anyway).
  Future<void> selectItem(
    WidgetTester tester, {
    required Key key,
    required String itemValue,
    required String itemLabel,
  }) async {
    await ensureFieldVisible(tester, key);

    final Finder dropdown = find.descendant(
      of: find.byKey(key),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown, findsOneWidget, reason: 'Expected exactly one DropdownButtonFormField<String> under key $key.');

    final Set<Element> scrollablesBeforeOpen = find.byType(Scrollable).evaluate().toSet();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final Finder visibleOption = await visiblePopupOption(
      tester,
      scrollablesBeforeOpen: scrollablesBeforeOpen,
      label: itemLabel,
    );

    await tester.tap(visibleOption);
    await tester.pumpAndSettle();

    final FormFieldState<String> state = tester.state<FormFieldState<String>>(dropdown);
    expect(
      state.value,
      itemValue,
      reason: 'Field $key did not reflect value "$itemValue" after selecting label "$itemLabel".',
    );
  }

  /// Scrolls the Save button into view before tapping it -- it can be
  /// off-screen on this scrollable form. See file-level doc comment,
  /// point 1. Uses the same deterministic [scrollPageUntilVisible]
  /// approach as [ensureFieldVisible].
  Future<void> save(WidgetTester tester, {String buttonLabel = 'Save'}) async {
    final Finder saveButton = find.text(buttonLabel);
    await scrollPageUntilVisible(tester, saveButton, description: "The '$buttonLabel' button");
    await tester.tap(saveButton.hitTestable());
    await tester.pumpAndSettle();
  }

  const Key homeCountryKey = Key('homeCountryField');
  const Key currentCountryKey = Key('currentCountryField');
  const Key homeCurrencyKey = Key('homeCurrencyField');
  const Key livingCurrencyKey = Key('livingCurrencyField');
  const Key languageKey = Key('languageField');
  const Key dateFormatKey = Key('dateFormatField');
  const Key numberFormatKey = Key('numberFormatField');
  const Key timezoneKey = Key('timezoneField');

  testWidgets('More shows the International preferences entry', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, startAtMore: true));
    await tester.pumpAndSettle();

    // MoreScreen's "International preferences" row is below the fold at
    // the default test surface -- reuses this file's own
    // scrollPageUntilVisible helper (see file-level doc comment, point 1)
    // rather than assuming it's already mounted.
    final Finder target = find.text('International preferences');
    await scrollPageUntilVisible(
      tester,
      target,
      description: 'The "International preferences" row on More',
    );
    expect(target, findsOneWidget);
  });

  testWidgets('tapping International preferences navigates to the new screen', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, startAtMore: true));
    await tester.pumpAndSettle();

    final Finder target = find.text('International preferences');
    await scrollPageUntilVisible(
      tester,
      target,
      description: 'The "International preferences" row on More',
    );
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.byType(InternationalPreferencesScreen), findsOneWidget);
  });

  testWidgets('the screen initially reflects all 8 persisted values', (tester) async {
    final (AppDatabase db, String profileId) =
        await seededDb(dateFormat: 'ymd', numberFormat: 'comma_period');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);

    // Each read scrolls its own field into view first -- do not assume
    // all 8 dropdowns are simultaneously instantiated on screen.
    expect(await fieldValue(tester, homeCountryKey), 'LK');
    expect(await fieldValue(tester, currentCountryKey), 'JP');
    expect(await fieldValue(tester, homeCurrencyKey), 'LKR');
    expect(await fieldValue(tester, livingCurrencyKey), 'JPY');
    expect(await fieldValue(tester, languageKey), 'en');
    expect(await fieldValue(tester, dateFormatKey), 'ymd');
    expect(await fieldValue(tester, numberFormatKey), 'comma_period');
    expect(await fieldValue(tester, timezoneKey), 'Asia/Tokyo');
  });

  testWidgets('changing Home country and Save persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    expect(await fieldValue(tester, homeCountryKey), 'US');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.homeCountry, 'US');
    expect(profile.currentCountry, 'JP'); // untouched
  });

  testWidgets('changing Current country and Save persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: currentCountryKey, itemValue: 'CA', itemLabel: 'Canada');
    expect(await fieldValue(tester, currentCountryKey), 'CA');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.currentCountry, 'CA');
    expect(profile.homeCountry, 'LK'); // untouched
  });

  testWidgets('changing Home currency and Save persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: homeCurrencyKey, itemValue: 'USD', itemLabel: 'USD — US Dollar');
    expect(await fieldValue(tester, homeCurrencyKey), 'USD');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.homeCurrency, 'USD');
    expect(profile.livingCurrency, 'JPY'); // untouched
  });

  testWidgets('changing Living currency and Save persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: livingCurrencyKey, itemValue: 'CAD', itemLabel: 'CAD — Canadian Dollar');
    expect(await fieldValue(tester, livingCurrencyKey), 'CAD');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.livingCurrency, 'CAD');
    expect(profile.homeCurrency, 'LKR'); // untouched
  });

  testWidgets('Language offers both English and Japanese as selectable options', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);

    expect(await fieldValue(tester, languageKey), 'en');

    // `DropdownMenuItem<String>` is not itself a hit-testable render
    // target in this Flutter version (3.47.2) -- the open popup route
    // builds its options from a different widget wrapping each item's
    // `child`, and `DropdownButtonFormField<String>` exposes no public
    // `items` getter to read configuration from instead. So what the
    // field actually OFFERS is read the same way `selectItem` reads it:
    // via [visiblePopupOption], which also handles the popup menu's own
    // internal `Scrollable` if the option isn't hit-testable yet --
    // deliberately not special-cased here, since both options are
    // expected to already be visible without scrolling.
    await ensureFieldVisible(tester, languageKey);
    final Finder languageDropdown = find.descendant(
      of: find.byKey(languageKey),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(languageDropdown, findsOneWidget);

    final Set<Element> scrollablesBeforeOpen = find.byType(Scrollable).evaluate().toSet();
    await tester.tap(languageDropdown);
    await tester.pumpAndSettle();

    // CP4.3 added 'ja' to `_languageCodes` and removed `_languageLabel`'s
    // "not yet selectable" branch entirely, so Japanese is now a normal
    // selectable option alongside English -- [visiblePopupOption] fails
    // loudly (rather than silently reporting zero matches) if either
    // label isn't present as exactly one hit-testable option.
    final Finder englishOption = await visiblePopupOption(
      tester,
      scrollablesBeforeOpen: scrollablesBeforeOpen,
      label: 'English',
    );
    await visiblePopupOption(
      tester,
      scrollablesBeforeOpen: scrollablesBeforeOpen,
      label: 'Japanese',
    );
    // No language should render with the old "(not yet selectable)"
    // suffix any more.
    expect(find.textContaining('not yet selectable').hitTestable(), findsNothing);

    // Close the popup the way a real user would -- by selecting the
    // currently-seeded option -- rather than leaving the route open.
    await tester.tap(englishOption);
    await tester.pumpAndSettle();

    expect(await fieldValue(tester, languageKey), 'en');
  });

  testWidgets('selecting Japanese and Save persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: languageKey, itemValue: 'ja', itemLabel: 'Japanese');
    expect(await fieldValue(tester, languageKey), 'ja');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.preferredLanguage, 'ja');
  });

  testWidgets('a Japanese-seeded profile opened in the Japanese locale renders Japanese proof text',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(preferredLanguage: 'ja');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container, locale: const Locale('ja'));
    expect(tester.takeException(), isNull);

    // The AppBar title, all 3 section headers, and the Save button all
    // render via `AppLocalizations.of(context)` -- this is proof the
    // Japanese locale actually renders translated strings end-to-end
    // inside this screen. (That `appLocaleProvider` itself maps 'ja' ->
    // `Locale('ja')` is already covered by
    // `test/core/locale/app_locale_provider_test.dart`, and that
    // `MaterialApp` is wired to honor a `Locale` at all is already
    // covered by `test/widget/app_locale_wiring_test.dart` -- this test
    // is the one that proves this screen's own strings actually use it.)
    expect(find.text('言語・地域設定'), findsOneWidget); // internationalPreferences (AppBar title)
    expect(find.text('地域'), findsOneWidget); // locationSection
    expect(find.text('通貨'), findsOneWidget); // currencySection

    // Repair Pass #1 (Failure 7): CP9.6 added a "Currency Converter" entry
    // point inside the Currency section, directly after ReferenceRateCard.
    // That extra content pushed this next section header below what used
    // to be reachable without scrolling in the test surface's default
    // viewport -- the screen itself is unchanged in every other respect and
    // remains fully scrollable, so this is a test-only fix, exactly the
    // same "start scrolling for this assertion" treatment the '保存' (Save)
    // button check right below already gets.
    final Finder languageAndFormatHeader = find.text('言語と表示形式'); // languageAndFormatSection
    await scrollPageUntilVisible(
      tester,
      languageAndFormatHeader,
      description: "The '言語と表示形式' section header",
    );
    expect(languageAndFormatHeader, findsOneWidget);

    final Finder saveButton = find.text('保存'); // save
    await scrollPageUntilVisible(tester, saveButton, description: "The '保存' (Save) button");
    expect(saveButton, findsOneWidget);
  });

  testWidgets('switching from Japanese to English and Save persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(preferredLanguage: 'ja');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    // This test harness's `locale:` is a static per-pump parameter --
    // unlike the real app's `appLocaleProvider`, it does not reactively
    // re-derive the rendered locale as the in-memory field selection
    // changes. So this test opens in the Japanese locale (matching the
    // seeded profile, and needed so the Save button's label -- itself
    // localized -- is findable), changes the Language field to English,
    // and asserts the *persisted* value after Save. English rendering
    // after such a switch is already covered compositionally by this
    // file's (English-locale-by-default) tests together with
    // `test/widget/app_locale_wiring_test.dart`, which proves the real
    // app's locale reactively follows `preferredLanguage` end-to-end.
    await openScreen(tester, container, locale: const Locale('ja'));
    expect(await fieldValue(tester, languageKey), 'ja');

    await selectItem(tester, key: languageKey, itemValue: 'en', itemLabel: 'English');
    expect(await fieldValue(tester, languageKey), 'en');

    await save(tester, buttonLabel: '保存');

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.preferredLanguage, 'en');
  });

  testWidgets('changing Date format persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: dateFormatKey, itemValue: 'dmy', itemLabel: 'Day, Month, Year (30-08-2026)');
    expect(await fieldValue(tester, dateFormatKey), 'dmy');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.dateFormat, 'dmy');
  });

  testWidgets('changing Number format persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: numberFormatKey, itemValue: 'period_comma', itemLabel: '1.234.567,89 (period thousands)');
    expect(await fieldValue(tester, numberFormatKey), 'period_comma');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.numberFormat, 'period_comma');
  });

  testWidgets('changing Timezone persists it', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: timezoneKey, itemValue: 'America/Toronto', itemLabel: 'Toronto (America/Toronto)');
    expect(await fieldValue(tester, timezoneKey), 'America/Toronto');

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.timezone, 'America/Toronto');
  });

  testWidgets('an unknown country renders safely and survives Save unchanged when another field '
      'changes', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(homeCountry: 'ZZ');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, homeCountryKey), 'ZZ');
    await ensureFieldVisible(tester, homeCountryKey);
    expect(find.text('Unknown (ZZ)'), findsOneWidget);

    await selectItem(tester, key: currentCountryKey, itemValue: 'CA', itemLabel: 'Canada');
    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.homeCountry, 'ZZ'); // preserved raw, unchanged
    expect(profile.currentCountry, 'CA'); // the field actually changed
  });

  testWidgets('an unknown currency renders safely and survives Save unchanged when another field '
      'changes', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(homeCurrency: 'ZZZ');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, homeCurrencyKey), 'ZZZ');
    await ensureFieldVisible(tester, homeCurrencyKey);
    expect(find.text('Unknown (ZZZ)'), findsOneWidget);

    await selectItem(tester, key: livingCurrencyKey, itemValue: 'CAD', itemLabel: 'CAD — Canadian Dollar');
    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.homeCurrency, 'ZZZ'); // preserved raw, unchanged
    expect(profile.livingCurrency, 'CAD');
  });

  testWidgets('an unknown language renders safely and survives an unrelated Save unchanged',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(preferredLanguage: 'xx');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, languageKey), 'xx');
    await ensureFieldVisible(tester, languageKey);
    expect(find.text('Unknown (xx)'), findsOneWidget);

    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.preferredLanguage, 'xx'); // preserved raw, unchanged
    expect(profile.homeCountry, 'US');
  });

  testWidgets('an unknown timezone renders safely and survives an unrelated Save unchanged',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(timezone: 'Not/AZone');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, timezoneKey), 'Not/AZone');
    await ensureFieldVisible(tester, timezoneKey);
    expect(find.text('Unknown (Not/AZone)'), findsOneWidget);

    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.timezone, 'Not/AZone'); // preserved raw, unchanged
    expect(profile.homeCountry, 'US');
  });

  testWidgets('legacy raw date_format "yyyy-MM-dd" survives an unrelated Save unchanged',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(); // default dateFormat: 'yyyy-MM-dd'
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, dateFormatKey), 'yyyy-MM-dd');
    await ensureFieldVisible(tester, dateFormatKey);
    // Resolves visually through the existing DateFormatRegistry alias --
    // never a crash, never a write.
    expect(find.text('Year, Month, Day (2026-08-30)'), findsOneWidget);

    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.dateFormat, 'yyyy-MM-dd'); // preserved raw, unchanged
    expect(profile.homeCountry, 'US');
  });

  testWidgets('legacy raw number_format "#,##0.##" survives an unrelated Save unchanged',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(); // default numberFormat: '#,##0.##'
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, numberFormatKey), '#,##0.##');
    await ensureFieldVisible(tester, numberFormatKey);
    expect(find.text('1,234,567.89 (comma thousands)'), findsOneWidget);

    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.numberFormat, '#,##0.##'); // preserved raw, unchanged
    expect(profile.homeCountry, 'US');
  });

  testWidgets('Save failure shows feedback and does not falsely indicate success', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pumpAndSettle();
      // db is deliberately already closed below -- do not close again.
    });

    await openScreen(tester, container);

    // Force the next repository write to fail.
    await db.close();

    await save(tester);

    // Still on the screen -- did not navigate away as if it had succeeded.
    expect(find.byType(InternationalPreferencesScreen), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
  });

  testWidgets('opening and leaving the screen without Save performs no repository write',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    final ProfileRow before = (await ProfileRepository(db).getProfile())!;

    await openScreen(tester, container);
    // Change a value in the UI, but never tap Save.
    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    expect(await fieldValue(tester, homeCountryKey), 'US');

    await tester.pageBack();
    await tester.pumpAndSettle();

    final ProfileRow after = (await ProfileRepository(db).getProfile())!;
    expect(after.homeCountry, before.homeCountry);
    expect(after.currentCountry, before.currentCountry);
    expect(after.homeCurrency, before.homeCurrency);
    expect(after.livingCurrency, before.livingCurrency);
    expect(after.preferredLanguage, before.preferredLanguage);
    expect(after.timezone, before.timezone);
    expect(after.dateFormat, before.dateFormat);
    expect(after.numberFormat, before.numberFormat);
    expect(after.updatedAt, before.updatedAt);
  });

  // CP5.3: International Preferences dropdown overflow hardening. These
  // tests are additive to the CP3B/CP4.3 coverage above -- they don't
  // re-check normal-regression persistence behavior (already covered by
  // "the screen initially reflects all 8 persisted values" and the
  // per-field "changing ... persists it" tests above) or the Japanese
  // language path (already covered by the three Japanese-specific tests
  // above); nothing about `isExpanded`/label-overflow wrapping changes
  // localization or persistence, so that existing coverage stands as the
  // regression guard for both. What's new here is narrow-width/large-
  // text-scale robustness for `_DropdownField`'s selected-value and
  // menu-item text, including the unknown-raw-value display path (which
  // renders through the exact same `_dropdownItem` helper as every known
  // value, so it needs the same overflow protection).
  //
  // A long *unknown* country code (rather than a real registry entry) is
  // used to stress "long label" scenarios below: none of
  // `CountryRegistry`/`TimezoneRegistry`'s current curated entries are
  // actually long enough to meaningfully stress this, and inventing one
  // would mean touching a registry file, which this checkpoint's scope
  // excludes. A long unknown value exercises the identical
  // `_itemsPreservingCurrentValue` synthetic-item code path a long
  // *known* label would, without touching any registry.
  const String longUnknownCountryCode =
      'ZZ-LEGACY-COUNTRY-CODE-FROM-A-DISCONTINUED-REGION-USED-FOR-STRESS-TESTING';

  testWidgets(
      'CP5.3: a long unknown-country label renders without an overflow exception at a narrow '
      '320px width, and merely opening the screen does not rewrite it', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId) =
        await seededDb(homeCountry: longUnknownCountryCode);
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    final ProfileRow before = (await ProfileRepository(db).getProfile())!;

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, homeCountryKey), longUnknownCountryCode);
    await ensureFieldVisible(tester, homeCountryKey);
    // Scoped to this specific field's own subtree -- not a page-wide
    // `find.text(...)` -- since a page-wide search would be ambiguous if
    // any other field ever happened to render the same unknown label.
    expect(
      find.descendant(
        of: find.byKey(homeCountryKey),
        matching: find.text('Unknown ($longUnknownCountryCode)'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // Merely opening the screen must not have written anything, even for
    // a field whose value is unknown to the registry -- same "no write
    // on open" guarantee the pre-existing "opening and leaving the
    // screen without Save performs no repository write" test proves for
    // known values, checked here specifically for the unknown-value/
    // overflow-hardened path.
    final ProfileRow afterOpenOnly = (await ProfileRepository(db).getProfile())!;
    expect(afterOpenOnly.homeCountry, before.homeCountry);
    expect(afterOpenOnly.currentCountry, before.currentCountry);
    expect(afterOpenOnly.homeCurrency, before.homeCurrency);
    expect(afterOpenOnly.livingCurrency, before.livingCurrency);
    expect(afterOpenOnly.preferredLanguage, before.preferredLanguage);
    expect(afterOpenOnly.timezone, before.timezone);
    expect(afterOpenOnly.dateFormat, before.dateFormat);
    expect(afterOpenOnly.numberFormat, before.numberFormat);
    expect(afterOpenOnly.updatedAt, before.updatedAt);
  });

  testWidgets(
      'CP5.3: a long unknown-country label renders without an overflow exception at a narrow '
      '320px width and a 1.6x text scale, and its raw value survives an unrelated Save',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) =
        await seededDb(homeCountry: longUnknownCountryCode);
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, homeCountryKey), longUnknownCountryCode);
    await ensureFieldVisible(tester, homeCountryKey);
    expect(
      find.descendant(
        of: find.byKey(homeCountryKey),
        matching: find.text('Unknown ($longUnknownCountryCode)'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // Change a different field and Save -- the long unknown value must
    // survive completely unchanged, exercising the "unknown raw value"
    // preservation policy at this narrow/large-text-scale condition
    // specifically (the equivalent normal-width case is already covered
    // by "an unknown country renders safely and survives Save unchanged
    // when another field changes" above).
    await selectItem(tester, key: currentCountryKey, itemValue: 'CA', itemLabel: 'Canada');
    await save(tester);
    expect(tester.takeException(), isNull);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.homeCountry, longUnknownCountryCode); // preserved raw, unchanged
    expect(profile.currentCountry, 'CA'); // the field actually changed
  });

  testWidgets(
      'CP5.3: the screen renders without an overflow exception and remains fully usable at a '
      'narrow 320px width and an extreme 2.0x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    expect(tester.takeException(), isNull);

    // At this extreme condition every field is checked, not just the
    // first: `isExpanded`/label-overflow protection applies uniformly
    // via the one shared `_DropdownField`/`_dropdownItem` code path, but
    // this confirms none of the 8 fields individually throws while being
    // scrolled to and read at 2.0x scale.
    expect(await fieldValue(tester, homeCountryKey), 'LK');
    expect(await fieldValue(tester, currentCountryKey), 'JP');
    expect(await fieldValue(tester, homeCurrencyKey), 'LKR');
    expect(await fieldValue(tester, livingCurrencyKey), 'JPY');
    expect(await fieldValue(tester, languageKey), 'en');
    expect(await fieldValue(tester, dateFormatKey), 'yyyy-MM-dd');
    expect(await fieldValue(tester, numberFormatKey), '#,##0.##');
    expect(await fieldValue(tester, timezoneKey), 'Asia/Tokyo');
    expect(tester.takeException(), isNull);

    // Vertical scrolling still reaches and successfully taps Save at
    // this scale -- explicitly allowed by this checkpoint's spec ("no
    // horizontal scrolling dropdown hacks", vertical scrolling is fine).
    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    await save(tester);
    expect(tester.takeException(), isNull);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.homeCountry, 'US');
  });

  // CP6.8 (Localization Phase 1): additive coverage the CP3B/CP4.3/CP5.3
  // suite above doesn't already provide -- a single Save that changes
  // all 8 fields atomically in one go, and the Japanese-locale x
  // large-text-scale x narrow-width combinations the existing Japanese
  // proof test and the existing CP5.3 (English-locale) stress tests
  // don't individually cover together. Nothing here weakens or replaces
  // any test above.
  testWidgets(
      'CP6.8 (H): a single Save persists all 8 changed international preference fields '
      'atomically', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container);
    await selectItem(tester, key: homeCountryKey, itemValue: 'US', itemLabel: 'United States');
    await selectItem(tester, key: currentCountryKey, itemValue: 'CA', itemLabel: 'Canada');
    await selectItem(tester, key: homeCurrencyKey, itemValue: 'USD', itemLabel: 'USD — US Dollar');
    await selectItem(
      tester,
      key: livingCurrencyKey,
      itemValue: 'CAD',
      itemLabel: 'CAD — Canadian Dollar',
    );
    await selectItem(tester, key: languageKey, itemValue: 'ja', itemLabel: 'Japanese');
    await selectItem(
      tester,
      key: dateFormatKey,
      itemValue: 'dmy',
      itemLabel: 'Day, Month, Year (30-08-2026)',
    );
    await selectItem(
      tester,
      key: numberFormatKey,
      itemValue: 'period_comma',
      itemLabel: '1.234.567,89 (period thousands)',
    );
    await selectItem(
      tester,
      key: timezoneKey,
      itemValue: 'America/Toronto',
      itemLabel: 'Toronto (America/Toronto)',
    );

    await save(tester);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.homeCountry, 'US');
    expect(profile.currentCountry, 'CA');
    expect(profile.homeCurrency, 'USD');
    expect(profile.livingCurrency, 'CAD');
    expect(profile.preferredLanguage, 'ja');
    expect(profile.dateFormat, 'dmy');
    expect(profile.numberFormat, 'period_comma');
    expect(profile.timezone, 'America/Toronto');
  });

  testWidgets(
      'CP6.8 (I): the screen renders without overflow under the Japanese locale at a 1.6x text '
      'scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb(preferredLanguage: 'ja');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container, locale: const Locale('ja'));
    expect(tester.takeException(), isNull);

    expect(find.text('言語・地域設定'), findsOneWidget);
    expect(await fieldValue(tester, homeCountryKey), 'LK');
    expect(await fieldValue(tester, timezoneKey), 'Asia/Tokyo');
    expect(tester.takeException(), isNull);

    final Finder saveButton = find.text('保存');
    await scrollPageUntilVisible(tester, saveButton, description: "The '保存' (Save) button");
    expect(saveButton, findsOneWidget);
  });

  testWidgets(
      'CP6.8 (J): the screen renders without overflow under the Japanese locale at an extreme '
      '2.0x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb(preferredLanguage: 'ja');
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container, locale: const Locale('ja'));
    expect(tester.takeException(), isNull);

    expect(find.text('言語・地域設定'), findsOneWidget);
    expect(await fieldValue(tester, homeCurrencyKey), 'LKR');
    expect(await fieldValue(tester, languageKey), 'ja');
    expect(tester.takeException(), isNull);

    final Finder saveButton = find.text('保存');
    await scrollPageUntilVisible(tester, saveButton, description: "The '保存' (Save) button");
    expect(saveButton, findsOneWidget);
  });

  testWidgets(
      'CP6.8 (K): a long unknown raw timezone value renders without an overflow exception under '
      'the Japanese locale at a narrow 320px width and a 1.6x text scale, and survives an '
      'unrelated Save unchanged', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const String longUnknownTimezone =
        'Not/A-Legacy-Timezone-Identifier-From-A-Discontinued-Region-Used-For-Stress-Testing';
    final (AppDatabase db, String profileId) =
        await seededDb(preferredLanguage: 'ja', timezone: longUnknownTimezone);
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await openScreen(tester, container, locale: const Locale('ja'));
    expect(tester.takeException(), isNull);
    expect(await fieldValue(tester, timezoneKey), longUnknownTimezone);
    await ensureFieldVisible(tester, timezoneKey);
    expect(
      find.descendant(
        of: find.byKey(timezoneKey),
        matching: find.text('Unknown ($longUnknownTimezone)'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await selectItem(tester, key: currentCountryKey, itemValue: 'CA', itemLabel: 'Canada');
    await save(tester, buttonLabel: '保存');
    expect(tester.takeException(), isNull);

    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    expect(profile!.timezone, longUnknownTimezone); // preserved raw, unchanged
    expect(profile.currentCountry, 'CA'); // the field actually changed
  });
}
