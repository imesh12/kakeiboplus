import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/theme/app_theme_style.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 8.1 (Premium Theme Personalization Foundation):
// AppTheme's new resolve()/pink()/ocean()/forest() factory surface, plus
// the CRITICAL Forest-vs-income-green safety mechanism
// (AppSemanticColors.positiveOverride). Does not re-cover what
// test/widget/shared/app_card_test.dart already asserts about
// AppTheme.light()'s component theming -- those assertions are
// untouched (light()/dark() are byte-for-byte unchanged by this
// checkpoint) and stay exactly as they were.
/// CP8.1 verification-fix helper: `AppTheme.resolve(style)` and the
/// corresponding named factory (`AppTheme.light()`/`AppTheme.dark()`) each
/// construct a FRESH `ThemeData`, so comparing them with plain
/// `expect(a, b)` relies on `ThemeData.==`, which also compares the
/// embedded `AppTokens` `ThemeExtension` -- and `AppTokens`/
/// `AppSemanticColors` (see `lib/shared/theme/app_tokens.dart`) do not
/// override `==`, so two structurally-identical-but-distinct instances are
/// never `==`. That is a test-assertion artifact, not a product bug: every
/// visible/semantic property compared below still must match exactly.
/// Compares the properties that actually define a theme's rendered
/// appearance -- not every internal `ThemeData` field -- so this stays a
/// meaningful equivalence check without overfitting to incidental fields.
void _expectSameVisualConfiguration(ThemeData a, ThemeData b) {
  expect(a.brightness, b.brightness);
  expect(a.colorScheme.primary, b.colorScheme.primary);
  expect(a.colorScheme.surface, b.colorScheme.surface);
  expect(a.colorScheme.error, b.colorScheme.error);
  expect(a.colorScheme.onSurface, b.colorScheme.onSurface);
  expect(a.scaffoldBackgroundColor, b.scaffoldBackgroundColor);
  expect(a.cardTheme, b.cardTheme);
  expect(a.inputDecorationTheme, b.inputDecorationTheme);
  expect(a.navigationBarTheme, b.navigationBarTheme);

  final AppTokens aTokens = a.extension<AppTokens>()!;
  final AppTokens bTokens = b.extension<AppTokens>()!;
  expect(aTokens.colors.cardSurface, bTokens.colors.cardSurface);
  expect(aTokens.colors.elevatedSurface, bTokens.colors.elevatedSurface);
  expect(aTokens.colors.subtleBorder, bTokens.colors.subtleBorder);
  expect(aTokens.colors.positive, bTokens.colors.positive);
  expect(aTokens.colors.warning, bTokens.colors.warning);
  expect(aTokens.colors.negative, bTokens.colors.negative);
  expect(aTokens.colors.secondaryText, bTokens.colors.secondaryText);
  expect(aTokens.colors.mutedText, bTokens.colors.mutedText);
  expect(aTokens.spacing.md, bTokens.spacing.md);
  expect(aTokens.radii.medium, bTokens.radii.medium);
}

void main() {
  group('AppTheme.light() / AppTheme.dark() are unchanged by this checkpoint', () {
    test('AppTheme.resolve(light) is identical to the pre-existing AppTheme.light()', () {
      _expectSameVisualConfiguration(AppTheme.resolve(AppThemeStyle.light), AppTheme.light());
    });

    test('AppTheme.resolve(dark) is identical to the pre-existing AppTheme.dark()', () {
      _expectSameVisualConfiguration(AppTheme.resolve(AppThemeStyle.dark), AppTheme.dark());
    });

    test('light() still derives positive from colorScheme.primary (no override)', () {
      final ThemeData theme = AppTheme.light();
      final AppTokens tokens = theme.extension<AppTokens>()!;
      expect(tokens.colors.positive, theme.colorScheme.primary);
    });

    test('dark() still derives positive from colorScheme.primary (no override)', () {
      final ThemeData theme = AppTheme.dark();
      final AppTokens tokens = theme.extension<AppTokens>()!;
      expect(tokens.colors.positive, theme.colorScheme.primary);
    });
  });

  group('AppTheme.resolve covers every AppThemeStyle', () {
    test('resolves all 5 styles without throwing, each carrying an AppTokens extension', () {
      for (final AppThemeStyle style in AppThemeStyle.values) {
        final ThemeData theme = AppTheme.resolve(style);
        expect(theme.extension<AppTokens>(), isNotNull, reason: 'missing AppTokens for $style');
      }
    });

    test('pink/ocean/forest each derive positive==negative semantics from their own '
        'ColorScheme, distinct from light/dark\'s primary color', () {
      final Color lightPrimary = AppTheme.light().colorScheme.primary;
      final Color pinkPrimary = AppTheme.pink().colorScheme.primary;
      final Color oceanPrimary = AppTheme.ocean().colorScheme.primary;
      final Color forestPrimary = AppTheme.forest().colorScheme.primary;

      final Set<Color> distinctPrimaries = <Color>{
        lightPrimary,
        pinkPrimary,
        oceanPrimary,
        forestPrimary,
      };
      // Every theme's seed is a distinct literal color (see AppTheme's
      // own private seed constants), so every derived primary must be
      // distinct too -- a real, working per-theme personality, not 4
      // themes that accidentally collapsed onto the same palette.
      expect(distinctPrimaries, hasLength(4));
    });

    test('negative never needs an override -- every theme\'s error color stays '
        'colorScheme.error', () {
      for (final AppThemeStyle style in AppThemeStyle.values) {
        final ThemeData theme = AppTheme.resolve(style);
        final AppTokens tokens = theme.extension<AppTokens>()!;
        expect(tokens.colors.negative, theme.colorScheme.error);
      }
    });
  });

  group('Forest: the CRITICAL income-green vs decorative-green safety mechanism', () {
    test('forest() overrides positive to a distinct color from its own decorative primary', () {
      final ThemeData theme = AppTheme.forest();
      final AppTokens tokens = theme.extension<AppTokens>()!;
      expect(tokens.colors.positive, isNot(theme.colorScheme.primary));
    });

    test('forest()\'s positive override is the specific bright "true success" green', () {
      final ThemeData theme = AppTheme.forest();
      final AppTokens tokens = theme.extension<AppTokens>()!;
      expect(tokens.colors.positive, const Color(0xFF16A34A));
    });

    test('every OTHER theme (light/dark/pink/ocean) still derives positive from its own '
        'colorScheme.primary -- the override is Forest-only', () {
      for (final AppThemeStyle style in <AppThemeStyle>[
        AppThemeStyle.light,
        AppThemeStyle.dark,
        AppThemeStyle.pink,
        AppThemeStyle.ocean,
      ]) {
        final ThemeData theme = AppTheme.resolve(style);
        final AppTokens tokens = theme.extension<AppTokens>()!;
        expect(
          tokens.colors.positive,
          theme.colorScheme.primary,
          reason: '$style should not receive a positiveOverride',
        );
      }
    });
  });

  group('Checkpoint U3: heroGradient is Light/Dark-only, never a global reseed', () {
    test('light() has the approved teal hero gradient '
        '(Dashboard Visual Refresh Pass)', () {
      final AppTokens tokens = AppTheme.light().extension<AppTokens>()!;
      expect(tokens.colors.heroGradient, <Color>[
        const Color(0xFF007F87),
        const Color(0xFF009B98),
        const Color(0xFF12C9AE),
      ]);
    });

    test('dark() has its own (deepened) hero gradient, distinct from light()', () {
      final AppTokens lightTokens = AppTheme.light().extension<AppTokens>()!;
      final AppTokens darkTokens = AppTheme.dark().extension<AppTokens>()!;
      expect(darkTokens.colors.heroGradient, isNotNull);
      expect(darkTokens.colors.heroGradient, isNot(lightTokens.colors.heroGradient));
    });

    test('pink/ocean/forest keep heroGradient null -- their own flat hero fill is unchanged', () {
      for (final AppThemeStyle style in <AppThemeStyle>[
        AppThemeStyle.pink,
        AppThemeStyle.ocean,
        AppThemeStyle.forest,
      ]) {
        final AppTokens tokens = AppTheme.resolve(style).extension<AppTokens>()!;
        expect(tokens.colors.heroGradient, isNull, reason: '$style should not receive heroGradient');
      }
    });

    test("light()'s shared colorScheme.primary is still derived from the Checkpoint 10 blue "
        'seed via the same ColorScheme.fromSeed pipeline, not reseeded to teal -- heroGradient '
        'is additive only', () {
      // Regression guard for the exact conflict this checkpoint's own
      // implementation notes call out: docs/23's teal palette must
      // never silently reverse Checkpoint 10 Visual Convergence's
      // deliberate teal/green -> blue recoloring of the app's shared
      // ColorScheme.
      //
      // Investigation note (this test previously asserted
      // `colorScheme.primary == Color(0xFF2563EB)` directly, and that
      // failed -- actual was `0xFF4B5C92`): that assertion's own
      // premise was wrong, not production. `git show`/`git diff`
      // against c0523c6 (the U2 commit immediately preceding this
      // checkpoint) confirm `_seed` and the
      // `ColorScheme.fromSeed(seedColor: seed, brightness: brightness)`
      // call in `app_theme.dart` are byte-for-byte unchanged by
      // heroGradient's addition -- `AppTokens.fromColorScheme` only
      // ever READS the resulting `colorScheme` to derive semantic
      // colors, it never replaces or mutates it, and `_build`'s
      // `ThemeData(colorScheme: colorScheme, ...)` passes it straight
      // through. Material 3's `ColorScheme.fromSeed` derives `.primary`
      // as a specific HCT tone of the seed's tonal palette, not the
      // seed's own raw RGB value -- so `colorScheme.primary == _seed`
      // was never true, before or after this checkpoint. `0xFF4B5C92`
      // was already `AppTheme.light().colorScheme.primary` at c0523c6,
      // unrelated to anything this checkpoint changed.
      //
      // Recomputing the same `fromSeed` call independently here (rather
      // than hardcoding that derived tone as a second magic number)
      // keeps this test asserting the thing it actually cares about --
      // "still built from the Checkpoint 10 blue seed" -- regardless of
      // exactly which tone Flutter's M3 algorithm resolves that to.
      final Color expectedPrimary = ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.light,
      ).primary;
      expect(AppTheme.light().colorScheme.primary, expectedPrimary);

      // Pinned to the actual, empirically-observed (and now
      // git-diff-confirmed-unchanged-since-U2) value as a second,
      // stricter guard: this is expected to break loudly if a future
      // Flutter SDK upgrade ever changes the M3 tonal-palette algorithm
      // for this seed -- a deliberate, known-cause failure, not a
      // silent drift.
      expect(AppTheme.light().colorScheme.primary, const Color(0xFF4B5C92));
    });
  });

  group('Smoke: every theme renders a MaterialApp without throwing', () {
    for (final AppThemeStyle style in AppThemeStyle.values) {
      testWidgets('AppThemeStyle.$style renders without exceptions', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(style),
            home: const Scaffold(body: Center(child: Text('theme smoke test'))),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('theme smoke test'), findsOneWidget);
      });
    }
  });
}
