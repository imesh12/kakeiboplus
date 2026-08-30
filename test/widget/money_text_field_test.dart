import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/shared/widgets/money_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget-level coverage of the release gate "currency-aware decimal
/// input behaves correctly for a 0-decimal, a 2-decimal, and a
/// 3-decimal currency" — see `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §14.
/// The underlying rules are already unit-tested in
/// `test/core/money/money_parser_test.dart`; this file confirms the
/// widget actually surfaces them through `FormState.validate()`.
void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Form(child: child)),
    );
  }

  testWidgets('JPY (0 minor units) rejects a typed fraction on validate', (tester) async {
    Money? parsed;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: MoneyTextField(currencyCode: 'JPY', onParsed: (m) => parsed = m),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '12.50');
    await tester.pump();
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.textContaining('JPY allows at most 0 decimal digit'), findsOneWidget);
    expect(parsed, isNull);
  });

  testWidgets('JPY accepts a whole-number amount', (tester) async {
    Money? parsed;
    await tester.pumpWidget(
      wrap(MoneyTextField(currencyCode: 'JPY', onParsed: (m) => parsed = m)),
    );
    await tester.enterText(find.byType(TextFormField), '1200');
    await tester.pump();
    expect(parsed, Money.fromMinorUnits(1200, 'JPY'));
  });

  testWidgets('KWD (3 minor units) accepts a 3-decimal amount', (tester) async {
    Money? parsed;
    await tester.pumpWidget(
      wrap(MoneyTextField(currencyCode: 'KWD', onParsed: (m) => parsed = m)),
    );
    await tester.enterText(find.byType(TextFormField), '1.234');
    await tester.pump();
    expect(parsed, Money.fromMinorUnits(1234, 'KWD'));
  });

  testWidgets('KWD rejects a 4-decimal amount on validate', (tester) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: MoneyTextField(currencyCode: 'KWD', onParsed: (_) {}),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '1.2345');
    await tester.pump();
    expect(formKey.currentState!.validate(), isFalse);
  });

  testWidgets('USD (2 minor units) accepts a standard 2-decimal amount', (tester) async {
    Money? parsed;
    await tester.pumpWidget(
      wrap(MoneyTextField(currencyCode: 'USD', onParsed: (m) => parsed = m)),
    );
    await tester.enterText(find.byType(TextFormField), '12.34');
    await tester.pump();
    expect(parsed, Money.fromMinorUnits(1234, 'USD'));
  });
}
