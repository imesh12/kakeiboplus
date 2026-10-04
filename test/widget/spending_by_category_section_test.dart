import 'dart:io';

import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/dashboard_providers.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/spending_by_category_section.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Ahem's square glyphs cannot validate real category-title fit. Load the
    // font bundled with the running Flutter SDK, without a project dependency.
    Directory root = File(Platform.resolvedExecutable).parent;
    File font;
    while (true) {
      font = File(
          '${root.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
      if (font.existsSync()) break;
      if (root.parent.path == root.path) {
        throw StateError('Flutter SDK Roboto font not found');
      }
      root = root.parent;
    }
    final loader = FontLoader('SpendingTestRoboto');
    loader
        .addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
  });

  const names = <String>[
    'Shopping',
    'Bills & Utilities',
    'Transport',
    'Dining out'
  ];
  const amounts = <int>[10000, 6000, 2500, 2500];
  const formatted = <String>['¥10,000', '¥6,000', '¥2,500', '¥2,500'];
  const percentages = <String>['48%', '29%', '12%', '12%'];

  for (final width in <double>[320, 390, 400, 430]) {
    for (final scale in <double>[1, 1.6]) {
      testWidgets('spending columns at $width px and ${scale}x',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = AppTheme.light();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            homeCategorySpendingProvider.overrideWithValue(AsyncData([
              for (int i = 0; i < names.length; i++)
                HomeCategorySpendingSlice(
                  categoryId: 'category-$i',
                  categoryName: names[i],
                  colorKey: null,
                  amount: Money.fromMinorUnits(amounts[i], 'JPY'),
                ),
            ])),
          ],
          child: MaterialApp(
            theme: theme.copyWith(
                textTheme:
                    theme.textTheme.apply(fontFamily: 'SpendingTestRoboto')),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
                body: Padding(
              padding: EdgeInsets.all(16),
              child: SpendingByCategorySection(),
            )),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final legend = find.byKey(const Key('spendingLegend'));
        final donutRect =
            tester.getRect(find.byKey(const Key('spendingDonut')));
        final legendRect = tester.getRect(legend);
        expect(donutRect.size, const Size(96, 96));
        if (width >= 400 || (width == 390 && scale == 1)) {
          expect(legendRect.left - donutRect.right, closeTo(12, 0.01));
          expect(legendRect.center.dy, closeTo(donutRect.center.dy, 0.01));
        } else {
          expect(legendRect.top, greaterThan(donutRect.bottom));
        }
        double? amountRight;
        double? percentRight;
        for (int i = 0; i < names.length; i++) {
          final name =
              find.descendant(of: legend, matching: find.text(names[i]));
          final row = find.ancestor(of: name, matching: find.byType(MergeSemantics));
          final amount =
              find.descendant(of: row, matching: find.text(formatted[i]));
          final percent =
              find.descendant(of: row, matching: find.text(percentages[i]));
          expect(name, findsOneWidget);
          expect(amount, findsOneWidget);
          expect(percent, findsOneWidget);
          expect(tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
              isFalse);
          expect(tester.renderObject<RenderParagraph>(amount).didExceedMaxLines,
              isFalse);
          expect(
              tester.renderObject<RenderParagraph>(percent).didExceedMaxLines,
              isFalse);
          final amountRect = tester.getRect(amount);
          final percentRect = tester.getRect(percent);
          expect(amountRect.center.dy, closeTo(percentRect.center.dy, 0.01));
          expect(tester.getRect(name).center.dy,
              closeTo(amountRect.center.dy, 0.01));
          expect(tester.widget<Text>(amount).textAlign, TextAlign.right);
          expect(tester.widget<Text>(percent).textAlign, TextAlign.right);
          amountRight ??= amountRect.right;
          percentRight ??= percentRect.right;
          expect(amountRect.right, closeTo(amountRight, 0.01));
          expect(percentRect.right, closeTo(percentRight, 0.01));
        }
      });
    }
  }
}
