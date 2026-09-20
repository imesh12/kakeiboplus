import 'dart:math' as math;

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/money/money_formatter.dart';
import 'package:ai_financial_coach/features/accounts/presentation/accounts_screen.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/home_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/more_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/settings_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/theme_customization_screen.dart';
import 'package:ai_financial_coach/features/transactions/presentation/activity_screen.dart';
import 'package:ai_financial_coach/features/transactions/presentation/add_transaction_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/theme/app_theme_style.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:ai_financial_coach/shared/widgets/app_card.dart';
import 'package:ai_financial_coach/shared/widgets/app_filter_chip.dart';
import 'package:ai_financial_coach/shared/widgets/app_finance_list_row.dart';
import 'package:ai_financial_coach/shared/widgets/app_icon_tile.dart';
import 'package:ai_financial_coach/shared/widgets/app_money_text.dart';
import 'package:ai_financial_coach/shared/widgets/app_progress_bar.dart';
import 'package:ai_financial_coach/shared/widgets/app_segmented_control.dart';
import 'package:ai_financial_coach/shared/widgets/app_status_chip.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 8.2 (Whole-App Theme Compatibility & Visual Polish): focused
// cross-theme coverage per the checkpoint's own Phase 5 minimum list.
// Deliberately NOT a fifth copy of every existing screen test file (the
// checkpoint's own "do not duplicate the entire widget suite five times"
// instruction) -- Light is already exhaustively covered by each screen's
// own test file, so every smoke test below targets Dark/Pink/Ocean/Forest
// specifically, reusing the exact seeding/container/disposal idioms already
// established across this repo's other widget tests (see
// `home_screen_test.dart`/`activity_screen_test.dart`/
// `accounts_screen_test.dart`/`add_transaction_screen_test.dart`/
// `settings_screen_test.dart`/`theme_customization_screen_test.dart`).
//
// None of the screens exercised here call `context.push`/navigate during
// their own `build` -- only from an `onTap` this file never triggers --
// so every smoke test below mounts its screen directly as `MaterialApp
// .home`, with no `GoRouter` ancestor needed.
const MoneyFormatter _formatter = MoneyFormatter();

void main() {
  /// Shared fixture: one profile (living JPY, home LKR), one JPY cash
  /// account with an opening balance, and one income + one expense
  /// transaction against it (seeded system categories) -- enough for
  /// Home/Activity/Accounts/Add Transaction/Settings to each render their
  /// real (non-empty) content under every theme, and for the Forest
  /// income-color regression test below to have an actual income row to
  /// inspect.
  Future<(AppDatabase, String profileId, String accountId)> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final AccountRepository accountRepo = AccountRepository(db);
    await CategoryRepository(db).seedSystemCategoriesIfNeeded();
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: 'LKR',
      livingCurrency: 'JPY',
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'JPY',
      openingBalance: Money.fromMinorUnits(50000, 'JPY'),
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final DateTime nowUtc = DateTime.now().toUtc();
    await txRepo.recordIncome(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(280000, 'JPY'),
      categoryId: 'sys-salary',
      occurredAtUtc: nowUtc,
    );
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      categoryId: 'sys-dining',
      occurredAtUtc: nowUtc,
    );
    return (db, profileId, accountId);
  }

  /// Same deterministic shutdown sequence every other screen test in this
  /// repo uses -- see e.g. `home_screen_test.dart`'s `disposeInOrder` for
  /// why the extra `pumpAndSettle()` before `db.close()` matters (Drift's
  /// `StreamQueryStore.markAsClosed` `Timer.zero`).
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  Widget appWithTheme(
    ProviderContainer container,
    Widget home,
    AppThemeStyle style,
  ) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.resolve(style),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  const List<AppThemeStyle> nonLightStyles = <AppThemeStyle>[
    AppThemeStyle.dark,
    AppThemeStyle.pink,
    AppThemeStyle.ocean,
    AppThemeStyle.forest,
  ];

  group('Phase 5.1/5.10/5.11: Home renders cleanly under every non-Light theme', () {
    for (final AppThemeStyle style in nonLightStyles) {
      testWidgets('AppThemeStyle.$style', (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithTheme(container, const HomeScreen(), style));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The hero currency card, the budget/goals/recurring empty
        // states, and the account list all render -- proves the screen
        // isn't silently failing to build under this theme, not just
        // that `Scaffold` itself didn't throw.
        expect(find.byKey(const Key('heroCurrencyCard_JPY')), findsOneWidget);
        // The Accounts section is the deepest section on Home and is
        // lazily built inside the screen's ListView -- every other test
        // in this repo that asserts on an account name scrolls to it
        // first (see `home_screen_test.dart`'s own account-name
        // assertions), so this does too instead of assuming it's already
        // mounted after a single `pumpAndSettle()`.
        await tester.scrollUntilVisible(find.text('Wallet'), 300.0);
        await tester.pumpAndSettle();
        expect(find.text('Wallet'), findsOneWidget);
      });
    }
  });

  group('Phase 5.2: Activity renders cleanly under Dark', () {
    testWidgets('shows the seeded income/expense rows without exceptions', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithTheme(container, const ActivityScreen(), AppThemeStyle.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Dining Out'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });
  });

  group('Phase 5.3: Accounts renders cleanly under Dark', () {
    testWidgets('shows the seeded account row without exceptions', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithTheme(container, const AccountsScreen(), AppThemeStyle.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Wallet'), findsOneWidget);
    });
  });

  group('Phase 5.4: Add Transaction renders cleanly under Dark', () {
    testWidgets('the Add Income form renders without exceptions', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithTheme(
          container,
          const AddTransactionScreen(initialType: 'income'),
          AppThemeStyle.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // `l10n.addIncomeTitle` (app_en.arb) is "Add income" -- lowercase
      // "income" -- not title-cased "Add Income".
      expect(find.text('Add income'), findsOneWidget);
    });
  });

  group('Phase 5.5: More renders cleanly under Dark', () {
    testWidgets('every nav row and the product disclaimer render without exceptions', (
      tester,
    ) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      // V1 Navigation Shell Implementation Checkpoint: this group used
      // to pump `SettingsScreen`, which owned every nav row and the
      // disclaimer under test here. Both moved to the new `MoreScreen`
      // (see `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 /
      // ADR-034 and `more_screen_test.dart`) -- `SettingsScreen` itself
      // is now just the identity card, so this dark-theme smoke test
      // retargets at `MoreScreen` to keep exercising the same rows and
      // disclaimer it always has, just through their new home.
      await tester.pumpWidget(appWithTheme(container, const MoreScreen(), AppThemeStyle.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Appearance'), findsOneWidget);
      // The disclaimer is the ListView's last child -- see the CP8.1
      // verification fix in `settings_screen_test.dart`'s pre-checkpoint
      // history for why this needs a scroll to become mounted before it
      // can be asserted on. The disclaimer copy no longer says "Beta 0"
      // (stale-copy correction -- see `app_en.arb`'s updated
      // `beta0DisclaimerMessage`) -- matched here on its new, accurate
      // opening phrase instead.
      final Finder disclaimer = find.textContaining('Multi-currency tracking');
      await tester.scrollUntilVisible(disclaimer, 300.0);
      await tester.pumpAndSettle();
      expect(disclaimer, findsOneWidget);
    });
  });

  group('Phase 5.6: Theme Customization renders cleanly under every theme (host theme)', () {
    for (final AppThemeStyle style in AppThemeStyle.values) {
      testWidgets('AppThemeStyle.$style', (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        // The host `MaterialApp.theme` below is deliberately varied too --
        // `ThemeCustomizationScreen` resolves each swatch's OWN preview
        // colors via `AppTheme.resolve` internally (see that screen's own
        // doc comment), so this also proves a swatch's preview never
        // leaks/depends on whichever theme happens to be currently active.
        await tester.pumpWidget(
          appWithTheme(container, const ThemeCustomizationScreen(), style),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final AppThemeStyle swatch in AppThemeStyle.values) {
          expect(find.byKey(Key('themeSwatch_${swatch.storageValue}')), findsOneWidget);
        }
      });
    }
  });

  group('Phase 5.7: shared AppCard/AppStatusChip/AppMoneyText resolve Dark tokens correctly', () {
    Widget buildDark(Widget child) {
      return MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: Center(child: child)));
    }

    testWidgets('AppCard(bordered: true) uses Dark colorScheme.surface + subtleBorder', (
      tester,
    ) async {
      await tester.pumpWidget(buildDark(const AppCard(bordered: true, child: Text('content'))));

      final BuildContext context = tester.element(find.text('content'));
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;
      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.color, colors.surface);
      final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);
      // Dark's `surface` and `subtleBorder` must actually differ -- an
      // invisible (same-color) border would defeat the whole point of
      // `bordered: true` on a theme with no shadow to fall back on.
      expect(colors.surface, isNot(tokens.colors.subtleBorder));
    });

    testWidgets('AppStatusChip label color matches the given semantic color under Dark', (
      tester,
    ) async {
      final ThemeData dark = AppTheme.dark();
      final AppTokens tokens = dark.extension<AppTokens>()!;
      await tester.pumpWidget(
        buildDark(AppStatusChip(label: 'Over budget', color: tokens.colors.negative)),
      );

      final Text text = tester.widget<Text>(find.text('Over budget'));
      expect(text.style?.color, tokens.colors.negative);
    });

    testWidgets('AppMoneyText renders the exact formatted string with an explicit color under Dark', (
      tester,
    ) async {
      final ThemeData dark = AppTheme.dark();
      final AppTokens tokens = dark.extension<AppTokens>()!;
      await tester.pumpWidget(
        buildDark(AppMoneyText('¥1,234', color: tokens.colors.positive)),
      );

      final Text text = tester.widget<Text>(find.text('¥1,234'));
      expect(text.style?.color, tokens.colors.positive);
    });
  });

  group('Phase 5.8: a dialog renders correctly under Dark', () {
    testWidgets('the Add Account dialog opens and its fields render without exceptions', (
      tester,
    ) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithTheme(container, const AccountsScreen(), AppThemeStyle.dark));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      // `l10n.addAccountDialogTitle` is "Add account"; the name field's
      // `l10n.accountNameLabel` is just "Name" (app_en.arb), not "Account
      // name".
      expect(find.text('Add account'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
    });
  });

  group('Phase 5.9 (Semantic Finance Safety regression): Forest income color', () {
    testWidgets(
      "Activity's income row uses AppTokens.colors.positive, not colorScheme.primary -- "
      'the two are deliberately DIFFERENT colors on Forest',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        final ThemeData forest = AppTheme.forest();
        final AppTokens tokens = forest.extension<AppTokens>()!;
        // This is the CP8.1 safety mechanism this test exists to protect --
        // if it ever stops holding, the assertions below would start
        // passing for the wrong reason (positive == primary), silently
        // losing their point.
        expect(
          tokens.colors.positive,
          isNot(forest.colorScheme.primary),
          reason: 'Forest positiveOverride must stay distinct from its own decorative primary',
        );

        await tester.pumpWidget(
          appWithTheme(container, const ActivityScreen(), AppThemeStyle.forest),
        );
        await tester.pumpAndSettle();

        final String incomeAmountText =
            '+${_formatter.format(Money.fromMinorUnits(280000, 'JPY'))}';
        final Text incomeText = tester.widget<Text>(find.text(incomeAmountText));

        expect(incomeText.style?.color, tokens.colors.positive);
        expect(incomeText.style?.color, isNot(forest.colorScheme.primary));
      },
    );
  });

  // Phase 5.10/5.11 (Pink/Ocean readable-contrast smoke): a static check on
  // each theme's own `ThemeData`, not a rendered widget tree -- pairs
  // AppTheme actually renders text/icons on top of (see `app_theme.dart`'s
  // component themes and every screen's `colors.onSurface`/`colors.error`/
  // `tokens.colors.positive` usage audited for this checkpoint) against
  // the WCAG 2.1 contrast-ratio formula. `onX`/`X` container pairs are
  // Material 3's own algorithm-guaranteed-accessible role pairs (>= 4.5:1
  // by construction, regardless of seed hue); the raw semantic accents
  // (`error`/`tokens.colors.positive`) are checked against >= 3.0:1 --
  // WCAG AA's "large text" threshold, matching how this app actually uses
  // them (bold `AppTypography.mediumMoney`/`largeMoney` figures and
  // status-chip labels, never small body text).
  double srgbToLinear(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  double relativeLuminance(Color c) =>
      0.2126 * srgbToLinear(c.r) + 0.7152 * srgbToLinear(c.g) + 0.0722 * srgbToLinear(c.b);

  double contrastRatio(Color a, Color b) {
    final double la = relativeLuminance(a) + 0.05;
    final double lb = relativeLuminance(b) + 0.05;
    return la > lb ? la / lb : lb / la;
  }

  group('Phase 5.10/5.11: Pink and Ocean meet WCAG-readable contrast on key pairs', () {
    for (final AppThemeStyle style in <AppThemeStyle>[AppThemeStyle.pink, AppThemeStyle.ocean]) {
      test('AppThemeStyle.$style', () {
        final ThemeData theme = AppTheme.resolve(style);
        final ColorScheme colors = theme.colorScheme;
        final AppTokens tokens = theme.extension<AppTokens>()!;

        expect(
          contrastRatio(colors.onSurface, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'primary body text vs. the screen background',
        );
        expect(
          contrastRatio(colors.onSurfaceVariant, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'secondary/muted text (AppTypography.caption/secondaryBody) vs. the background',
        );
        expect(
          contrastRatio(colors.onPrimaryContainer, colors.primaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: 'the hero currency card\'s own text vs. its filled background',
        );
        expect(
          contrastRatio(colors.error, colors.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'expense amounts (bold, large) vs. the background',
        );
        expect(
          contrastRatio(tokens.colors.positive, colors.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'income amounts (bold, large) vs. the background',
        );
      });
    }
  });

  group('Phase 5.12: enlarged text under a non-Light theme', () {
    testWidgets('Settings/Profile renders without overflow under Dark at a 2.0x text scale', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithTheme(container, const SettingsScreen(), AppThemeStyle.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // At 2.0x scale the "Appearance" row (further down the body
      // ListView) can be pushed out of the viewport, unlike at the
      // default scale -- assert on the AppBar title instead, which stays
      // fixed and visible regardless of body text scale (the same
      // approach `settings_screen_test.dart`'s own 1.6x/2.0x Japanese
      // scale tests use).
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  // Checkpoint 10 (Icon-Led UI Foundation): the new shared foundation
  // primitives (AppIconTile, AppFinanceListRow, AppSegmentedControl,
  // AppProgressBar, AppFilterChip, AppCard's softShadow) each already have
  // their own dedicated test file under `test/widget/shared/` proving
  // their individual contracts -- this group instead proves what those
  // per-widget files can't: that all of them render together, without
  // exception, under every one of the app's 5 themes, matching this
  // file's own existing "cross-theme smoke" pattern (Phase 5.1-5.8) --
  // plus that CP10's new `info` semantic color and `ambientGradient`
  // token stay visually distinct/restrained on every theme, the same way
  // Phase 5.9 already guards `positive` for Forest.
  group('Phase 6.1: every CP10 foundation primitive renders under every theme', () {
    for (final AppThemeStyle style in AppThemeStyle.values) {
      testWidgets('AppThemeStyle.$style', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(style),
            home: Scaffold(
              body: ListView(
                children: <Widget>[
                  const AppIconTile(icon: Icons.restaurant, color: Colors.deepOrange),
                  const AppCard(
                    softShadow: true,
                    child: AppFinanceListRow(
                      leadingIcon: Icons.movie,
                      leadingColor: Colors.red,
                      title: 'Netflix',
                      subtitle: 'Next: Sep 18, 2026',
                      trailing: AppMoneyText('-¥1,590'),
                    ),
                  ),
                  AppSegmentedControl<String>(
                    options: const <AppSegmentedControlOption<String>>[
                      AppSegmentedControlOption<String>(value: 'all', label: 'All'),
                      AppSegmentedControlOption<String>(value: 'cash', label: 'Cash'),
                    ],
                    selected: 'all',
                    onChanged: (_) {},
                  ),
                  const AppProgressBar(value: 0.65, color: Colors.green),
                  AppFilterChip(label: 'Expense', selected: true, onSelected: (_) {}),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Netflix'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
      });
    }
  });

  group('Phase 6.2 (Semantic Finance Safety, extended): info stays distinct from '
      'positive/warning/negative on every theme', () {
    for (final AppThemeStyle style in AppThemeStyle.values) {
      test('AppThemeStyle.$style', () {
        final ThemeData theme = AppTheme.resolve(style);
        final AppTokens tokens = theme.extension<AppTokens>()!;
        final Set<Color> distinctSemanticColors = <Color>{
          tokens.colors.positive,
          tokens.colors.warning,
          tokens.colors.negative,
          tokens.colors.info,
        };
        expect(
          distinctSemanticColors,
          hasLength(4),
          reason:
              'positive/warning/negative/info must resolve to 4 visually distinct colors, '
              'never collapsing onto the same ColorScheme role',
        );
      });
    }
  });

  group('Phase 6.3: the ambient gradient token stays restrained (never opaque/recoloring)', () {
    for (final AppThemeStyle style in AppThemeStyle.values) {
      test('AppThemeStyle.$style', () {
        final ThemeData theme = AppTheme.resolve(style);
        final AppTokens tokens = theme.extension<AppTokens>()!;
        for (final Color stop in tokens.colors.ambientGradient) {
          expect(
            stop.a,
            lessThanOrEqualTo(0.10),
            reason: 'every ambientGradient stop must stay low-alpha -- decorative only, '
                'never a solid recolor of the surface it washes over',
          );
        }
      });
    }
  });
}
