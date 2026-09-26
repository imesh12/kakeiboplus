import 'package:ai_financial_coach/core/finance/card_network.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/widgets/card_network_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
// Foundation): `CardNetworkBadge` -- shown only when genuinely known,
// text-only (never a recreated brand logo), reusing the exact same
// localized labels `add_account_form_screen.dart`'s network dropdown
// already established.

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('a null network renders the neutral generic fallback label, never fabricated',
      (tester) async {
    await tester.pumpWidget(_wrap(const CardNetworkBadge(network: null)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Card'), findsOneWidget);
  });

  testWidgets('every known CardNetwork renders its own distinct, non-empty label',
      (tester) async {
    final Set<String> seen = <String>{};
    for (final CardNetwork network in CardNetwork.values) {
      await tester.pumpWidget(_wrap(CardNetworkBadge(network: network)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Text text = tester.widget<Text>(find.byType(Text));
      expect(text.data, isNotEmpty, reason: network.storageValue);
      seen.add(text.data!);
    }
    expect(seen.length, CardNetwork.values.length, reason: 'every network must have a distinct label');
  });

  testWidgets('reuses the exact same localized label add_account_form_screen already shows for Visa',
      (tester) async {
    await tester.pumpWidget(_wrap(const CardNetworkBadge(network: CardNetwork.visa)));
    await tester.pumpAndSettle();
    expect(find.text('Visa'), findsOneWidget);
  });

  testWidgets('renders correctly under the Japanese locale too', (tester) async {
    await tester.pumpWidget(
      _wrap(const CardNetworkBadge(network: CardNetwork.jcb), locale: const Locale('ja')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('JCB'), findsOneWidget);
  });
}
