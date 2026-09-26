import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/widgets/currency_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
// Foundation): `CurrencyBadge` -- the currency code stays authoritative
// and always visible; the region monogram is optional secondary
// decoration; EUR (multi-region) never renders a single arbitrarily-
// chosen country.

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('always shows the currency code, even for an unrecognized/future code', (tester) async {
    await tester.pumpWidget(_wrap(const CurrencyBadge(currencyCode: 'XYZ')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('XYZ'), findsOneWidget);
  });

  testWidgets('showRegionIndicator=false (the default) never renders a region glyph', (tester) async {
    await tester.pumpWidget(_wrap(const CurrencyBadge(currencyCode: 'JPY')));
    await tester.pumpAndSettle();
    expect(find.text('JPY'), findsOneWidget);
    expect(find.text('JP'), findsNothing);
  });

  testWidgets('showRegionIndicator=true adds the JP glyph for JPY, alongside the code',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const CurrencyBadge(currencyCode: 'JPY', showRegionIndicator: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('JPY'), findsOneWidget);
    expect(find.text('JP'), findsOneWidget);
  });

  testWidgets('EUR renders the neutral EU region glyph, never a single Eurozone country',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const CurrencyBadge(currencyCode: 'EUR', showRegionIndicator: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('EU'), findsOneWidget);
    expect(find.text('DE'), findsNothing);
    expect(find.text('FR'), findsNothing);
  });

  testWidgets('a currency code with no deliberate region glyph shows no glyph at all, not a guess',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const CurrencyBadge(currencyCode: 'XYZ', showRegionIndicator: true)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('XYZ'), findsOneWidget);
    // Exactly one Text -- no second (glyph) Text was added.
    expect(find.byType(Text), findsOneWidget);
  });
}
