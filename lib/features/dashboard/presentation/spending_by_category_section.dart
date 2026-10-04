import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../categories/domain/category_color.dart';
import 'dashboard_providers.dart';

const MoneyFormatter _spendingFormatter = MoneyFormatter();

/// "Spending this month" -- Dashboard V1 Finalization checkpoint. A
/// donut chart (left) + category legend (right/below), fed entirely by
/// [homeCategorySpendingProvider] (itself built on
/// `FinanceEngine.categoryExpenseTotals`, the same deterministic,
/// expense-only, transfer-excluded aggregation the budgets feature's
/// per-category "spent" figure already uses). Every color comes from
/// [categoryColorFor] -- the U1 category-identity palette every other
/// screen already uses -- never a new Dashboard-only chart palette.
///
/// The donut itself is drawn with a plain [CustomPainter] rather than a
/// charting package: no chart dependency exists in `pubspec.yaml` today,
/// and adding one would require a `flutter pub get` this environment
/// cannot run, leaving the project unresolved until a human runs it --
/// a dependency-free painter avoids that risk entirely and matches the
/// project's "no unnecessary dependencies" rule.
class SpendingByCategorySection extends ConsumerWidget {
  const SpendingByCategorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<HomeCategorySpendingSlice>> spendingAsync =
        ref.watch(homeCategorySpendingProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSectionHeader(
          assetPath: 'assets/icons/dashboard/spending_chart.png',
            assetSize: 28,
            titleStyle: context.appTypography.sectionTitle?.copyWith(fontSize: 14),
          title: l10n.homeSpendingThisMonthTitle,
          eyebrow: true,
          // No dedicated category-spending detail screen exists yet
          // (out of scope for this checkpoint -- see
          // docs/23_DASHBOARD_HEADER_BRAND_SPEC.md §36's "no
          // category-management redesign" boundary) -- "View details"
          // reuses the existing Activity screen, the real destination
          // for looking at the underlying transactions, rather than
          // inventing a new screen or a dead link.
          trailing: TextButton(
            key: const Key('spendingViewDetailsButton'),
            onPressed: () => context.push(AppRoutes.activity),
            child: Text(l10n.homeViewDetails),
          ),
        ),
        const SizedBox(height: 6),
        AppCard(
          key: const Key('spendingByCategoryCard'),
          bordered: true,
          softShadow: true,
          child: spendingAsync.when(
            loading: () => const SizedBox(
              height: 24,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (Object error, StackTrace stackTrace) => Text(
              l10n.homeSpendingNoDataMessage,
              style: context.appTypography.secondaryBody,
            ),
            data: (List<HomeCategorySpendingSlice> slices) => slices.isEmpty
                ? Text(
                    l10n.homeSpendingNoDataMessage,
                    key: const Key('spendingEmptyMessage'),
                    style: context.appTypography.secondaryBody,
                  )
                : _SpendingBreakdown(slices: slices),
          ),
        ),
      ],
    );
  }
}

/// Real spending proportions with a compact, measured three-column legend.
class _SpendingBreakdown extends StatelessWidget {
  const _SpendingBreakdown({required this.slices});

  final List<HomeCategorySpendingSlice> slices;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final int totalMinorUnits = slices.fold<int>(
        0, (int sum, HomeCategorySpendingSlice s) => sum + s.amount.minorUnits);

    final List<Color> sliceColors = <Color>[
      for (final HomeCategorySpendingSlice slice in slices)
        slice.categoryId == null
            ? categoryColorForKey(CategoryColorKey.slate, isDark: isDark)
            : categoryColorFor(
                categoryId: slice.categoryId!,
                storedColorKey: slice.colorKey,
                isDark: isDark,
              ),
    ];

    final Widget donut = SizedBox(
      key: const Key('spendingDonut'),
      width: 96,
      height: 96,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _DonutChartPainter(
            values: <double>[
              for (final HomeCategorySpendingSlice slice in slices)
                slice.amount.minorUnits.toDouble(),
            ],
            colors: sliceColors,
            trackColor: colors.surfaceContainerHighest,
          ),
        ),
      ),
    );

    final text = Theme.of(context).textTheme;
    final categoryStyle = text.bodySmall!.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: 0,
      color: colors.onSurface,
    );
    final amountStyle =
        categoryStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
    final percentStyle =
        categoryStyle.copyWith(fontSize: 10, color: colors.onSurfaceVariant);
    final names = <String>[
      for (final slice in slices)
        slice.categoryName ?? l10n.homeUncategorizedCategoryLabel,
    ];
    final amounts = <String>[
      for (final slice in slices) _spendingFormatter.format(slice.amount),
    ];
    final percentages = <String>[
      for (final slice in slices)
        l10n.homeCategoryPercentLabel(
          totalMinorUnits == 0
              ? '0'
              : ((slice.amount.minorUnits / totalMinorUnits) * 100)
                  .round()
                  .toString(),
        ),
    ];
    double widest(List<String> labels, TextStyle style) {
      double width = 0;
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        width = math.max(width, painter.width.ceilToDouble());
        painter.dispose();
      }
      return width;
    }

    final amountWidth = widest(amounts, amountStyle);
    final percentWidth = widest(percentages, percentStyle);
    // Dot + three compact gaps. Numeric columns reserve only their real width.
    final fixedWidth = 8 + 4 + 4 + 6 + amountWidth + percentWidth;
    final fullLegendWidth = fixedWidth + widest(names, categoryStyle);
    final legend = Column(
      key: const Key('spendingLegend'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < slices.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == slices.length - 1 ? 0 : 6),
            child: _LegendRow(
              name: names[i],
              amount: amounts[i],
              percent: percentages[i],
              color: sliceColors[i],
              amountWidth: amountWidth,
              percentWidth: percentWidth,
              categoryStyle: categoryStyle,
              amountStyle: amountStyle,
              percentStyle: percentStyle,
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Use the real localized/scaled strings to decide whether the legend
        // can share a row with the donut without truncating category names.
        final stacked = constraints.maxWidth < 300 ||
            constraints.maxWidth - 96 - 12 < fullLegendWidth;
        if (stacked) {
          // Exceptional amounts retain all digits even if the numeric columns
          // alone exceed a narrow viewport. Normal stacked legends do not scroll.
          final legendWidth = math.max(constraints.maxWidth, fixedWidth + 48);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: donut),
              const SizedBox(height: 12),
              if (legendWidth > constraints.maxWidth)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: legendWidth, child: legend),
                )
              else
                legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            donut,
            const SizedBox(width: 12),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
    required this.amountWidth,
    required this.percentWidth,
    required this.categoryStyle,
    required this.amountStyle,
    required this.percentStyle,
  });

  final String name;
  final String amount;
  final String percent;
  final Color color;
  final double amountWidth;
  final double percentWidth;
  final TextStyle categoryStyle;
  final TextStyle amountStyle;
  final TextStyle percentStyle;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: categoryStyle),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: amountWidth,
            child: Text(amount,
                maxLines: 1, textAlign: TextAlign.right, style: amountStyle),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: percentWidth,
            child: Text(percent,
                maxLines: 1, textAlign: TextAlign.right, style: percentStyle),
          ),
        ],
      ),
    );
  }
}

/// Draws a simple ring ("donut") chart: one stroked arc per value,
/// proportional to its share of the total, clockwise from the top. Pure
/// [CustomPainter] -- no chart package dependency (see this file's own
/// doc comment for why). A zero-total list (should not occur here since
/// [SpendingByCategorySection] only reaches this widget for non-empty,
/// positive-amount slices, but kept defensive) draws only the neutral
/// track, never divides by zero.
class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double shortestSide = size.shortestSide;
    final double strokeWidth = shortestSide * 0.22;
    final Rect ovalRect =
        Rect.fromLTWH(0, 0, size.width, size.height).deflate(strokeWidth / 2);

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(ovalRect, 0, 2 * math.pi, false, trackPaint);

    final double total =
        values.fold<double>(0, (double sum, double v) => sum + v);
    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final double sweep = (values[i] / total) * 2 * math.pi;
      if (sweep <= 0) continue;
      final Paint slicePaint = Paint()
        // Each arc owns its shader; category boundaries/proportions stay exact.
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          transform: GradientRotation(startAngle),
          colors: <Color>[
            colors[i],
            Color.lerp(colors[i], Colors.white, 0.18)!,
          ],
        ).createShader(ovalRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(ovalRect, startAngle, sweep, false, slicePaint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
