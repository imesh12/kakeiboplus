import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual System Convergence Checkpoint 7.1 §16: focused widget tests for
/// the shared [AppMoneyText] primitive. Per the checkpoint's LOCKED
/// money-display rules (§10), this widget must never ellipsize, truncate, or
/// drop a digit of the already-formatted string it is given -- these tests
/// assert on the exact rendered string and its `Text` properties rather than
/// re-deriving formatting, since `AppMoneyText` never formats money itself.
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));
  }

  testWidgets('renders the exact formatted string it is given, verbatim', (tester) async {
    await tester.pumpWidget(buildApp(const AppMoneyText('¥1,250,000')));

    expect(find.text('¥1,250,000'), findsOneWidget);
  });

  testWidgets('never truncates a large formatted amount -- no ellipsis, no maxLines cap', (
    tester,
  ) async {
    const String large = '₫999,999,999,999';
    await tester.pumpWidget(buildApp(const AppMoneyText(large)));

    final Text widget = tester.widget<Text>(find.text(large));
    expect(widget.overflow, isNot(TextOverflow.ellipsis));
    expect(widget.maxLines, isNull);
  });

  testWidgets('renders a KWD (3-decimal) formatted amount in full', (tester) async {
    const String kwd = 'د.ك12,345.678';
    await tester.pumpWidget(buildApp(const AppMoneyText(kwd)));

    expect(find.text(kwd), findsOneWidget);
  });

  testWidgets('renders an MMK (2-decimal) formatted amount in full', (tester) async {
    const String mmk = 'K5,000,000.00';
    await tester.pumpWidget(buildApp(const AppMoneyText(mmk)));

    expect(find.text(mmk), findsOneWidget);
  });

  testWidgets('every digit remains present at 2.0x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    const String amount = 'KWD 1,250.375';
    await tester.pumpWidget(
      buildApp(const AppMoneyText(amount, emphasis: AppMoneyEmphasis.hero)),
    );
    await tester.pumpAndSettle();

    expect(find.text(amount), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an explicit color overrides the role default without changing the text', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const AppMoneyText('-¥1,280', color: Colors.red)));

    final Text widget = tester.widget<Text>(find.text('-¥1,280'));
    expect(widget.style?.color, Colors.red);
  });

  testWidgets('hero, primary, and secondary emphasis resolve to distinct descending sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const Column(
          children: <Widget>[
            AppMoneyText('1', key: Key('hero'), emphasis: AppMoneyEmphasis.hero),
            AppMoneyText('2', key: Key('primary')),
            AppMoneyText('3', key: Key('secondary'), emphasis: AppMoneyEmphasis.secondary),
          ],
        ),
      ),
    );

    // The key sits on `AppMoneyText` itself (matching how call sites key it,
    // e.g. `home_screen.dart`'s `heroCurrencyCard_<code>`), not on the
    // `Text` it builds internally -- so the actual rendered style is read
    // off the descendant `Text`, not the keyed widget itself.
    double fontSizeOf(Key key) => tester
        .widget<Text>(find.descendant(of: find.byKey(key), matching: find.byType(Text)))
        .style!
        .fontSize!;

    final double heroSize = fontSizeOf(const Key('hero'));
    final double primarySize = fontSizeOf(const Key('primary'));
    final double secondarySize = fontSizeOf(const Key('secondary'));

    expect(heroSize, greaterThan(primarySize));
    expect(primarySize, greaterThan(secondarySize));
  });
}
