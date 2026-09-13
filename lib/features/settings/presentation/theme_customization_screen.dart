import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/app_theme_provider.dart';
import '../../../shared/theme/app_theme_style.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// Checkpoint 8.1 (Premium Theme Personalization Foundation), Phase 5:
/// the dedicated Theme Customization surface reached from the
/// Profile/Settings screen's new "Appearance" row.
///
/// # Scope -- why this screen is smaller than the full design reference
///
/// The approved Claude Design "Theme Customization" reference
/// (`docs/design/theme-customization.png`) shows considerably more than
/// theme selection -- color customization, background style, font size,
/// rounded corners, and per-card visibility toggles. This checkpoint's
/// own text is explicit that it is a "Foundation" and "Do NOT add
/// additional themes in this checkpoint", so only the reference's
/// "PRESET THEMES" swatch-selection row is implemented here. Everything
/// else in that mockup is future/out-of-scope personalization work for
/// a later checkpoint (tracked, not guessed at, in this checkpoint's
/// own final report) -- this screen does not pretend to offer it.
///
/// # No duplicated theme colors
///
/// Every swatch's preview colors come from [AppTheme.resolve], the
/// exact same factory `lib/app/app.dart` uses to build the live active
/// theme -- see [_ThemeSwatchCard]. Nothing here hard-codes a second
/// copy of any theme's palette.
///
/// # Immediate apply, no Save button
///
/// Tapping a swatch calls [ProfileRepository.updateThemePreference]
/// directly and persists immediately -- there is no local "pending"
/// selection state and no Save button. Because [activeProfileProvider]
/// is a live Drift stream (see that provider's own doc comment) and
/// [appThemeStyleProvider] derives from it, the write's effect is
/// visible everywhere in the app (including this screen's own selected-
/// swatch highlight) on the very next frame, with no restart.
class ThemeCustomizationScreen extends ConsumerWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    final AppThemeStyle selected = ref.watch(appThemeStyleProvider);

    Future<void> select(AppThemeStyle style, String profileId) async {
      // A no-op re-tap of the already-selected swatch still shouldn't
      // issue a redundant write.
      if (style == selected) return;
      await ref.read(profileRepositoryProvider).updateThemePreference(
            profileId: profileId,
            themePreference: style.storageValue,
          );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeCustomizationTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text(l10n.couldNotLoadProfile('$e'))),
        data: (ProfileRow? profile) {
          if (profile == null) return const SizedBox.shrink();
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(l10n.themeCustomizationSubtitle, style: context.appTypography.secondaryBody),
                const SizedBox(height: 24),
                Text(l10n.presetThemesSectionTitle, style: context.appTypography.eyebrow),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: <Widget>[
                    for (final AppThemeStyle style in AppThemeStyle.values)
                      _ThemeSwatchCard(
                        key: Key('themeSwatch_${style.storageValue}'),
                        style: style,
                        label: _themeStyleLabel(l10n, style),
                        selected: style == selected,
                        selectedSemanticSuffix: l10n.themeSelectedSemanticLabel,
                        onTap: () => select(style, profile.id),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.themeCustomizationPrivacyDisclaimer,
                  style: context.appTypography.caption,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Localized display name for a theme -- never the persisted
/// [AppThemeStyle.storageValue] identifier itself.
String _themeStyleLabel(AppLocalizations l10n, AppThemeStyle style) {
  return switch (style) {
    AppThemeStyle.light => l10n.themeStyleLight,
    AppThemeStyle.dark => l10n.themeStyleDark,
    AppThemeStyle.pink => l10n.themeStylePink,
    AppThemeStyle.ocean => l10n.themeStyleOcean,
    AppThemeStyle.forest => l10n.themeStyleForest,
  };
}

/// One compact, tappable theme preview -- deliberately NOT a miniature
/// screenshot of the whole app (per this checkpoint's own "compact,
/// not a full miniature app screenshot" guidance). A small
/// background/card-surface/primary-accent/text-indication/progress-cue
/// composition is enough for the theme's personality to read at a
/// glance, matching the reference mockup's own circular-swatch density.
///
/// The selected state is communicated through THREE independent
/// signals, never color alone (this checkpoint's own accessibility
/// requirement): a thicker, primary-colored border; a check-mark badge;
/// and a `Semantics.selected`/announced-suffix label a screen reader
/// exposes regardless of how the badge renders visually.
class _ThemeSwatchCard extends StatelessWidget {
  const _ThemeSwatchCard({
    super.key,
    required this.style,
    required this.label,
    required this.selected,
    required this.selectedSemanticSuffix,
    required this.onTap,
  });

  final AppThemeStyle style;
  final String label;
  final bool selected;
  final String selectedSemanticSuffix;
  final VoidCallback onTap;

  static const double _swatchSize = 84;

  @override
  Widget build(BuildContext context) {
    // Reuses the exact same theme definitions the live app applies --
    // see the class doc comment on ThemeCustomizationScreen.
    final ThemeData previewTheme = AppTheme.resolve(style);
    final ColorScheme previewColors = previewTheme.colorScheme;
    final AppTokens previewTokens =
        previewTheme.extension<AppTokens>() ?? AppTokens.fromColorScheme(previewColors);
    final ColorScheme hostColors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, $selectedSemanticSuffix' : label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: _swatchSize,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: _swatchSize,
                    height: _swatchSize,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: previewColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? previewColors.primary : hostColors.outlineVariant,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Text-indication cue.
                            Container(
                              width: 26,
                              height: 7,
                              decoration: BoxDecoration(
                                color: previewColors.onSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Card-surface cue, holding a primary-accent
                            // cue and a small progress/positive-money
                            // cue.
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: previewTokens.colors.cardSurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    Container(
                                      width: 18,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: previewColors.primary,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: previewTokens.colors.positive,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (selected)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: previewColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: previewColors.surface, width: 1.5),
                              ),
                              child: Icon(Icons.check, size: 11, color: previewColors.onPrimary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.appTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
