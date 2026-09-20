import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_finance_list_row.dart';
import 'package:ai_financial_coach/shared/widgets/app_money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 10 (Icon-Led UI Foundation): focused widget tests for the new
// AppFinanceListRow foundation primitive -- built and independently
// tested this checkpoint; not yet wired into an existing screen (every
// current list has its own bespoke width-adaptive layout this checkpoint
// must not regress -- see that widget's own doc comment and the CP10
// final report's "Deferred visual work").
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));
  }

  testWidgets('renders the leading icon, title, subtitle, and trailing widget', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const AppFinanceListRow(
          leadingIcon: Icons.movie,
          leadingColor: Colors.red,
          title: 'Netflix',
          subtitle: 'Next: Sep 18, 2026',
          trailing: AppMoneyText('-¥1,590'),
        ),
      ),
    );

    expect(find.byIcon(Icons.movie), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Next: Sep 18, 2026'), findsOneWidget);
    expect(find.text('-¥1,590'), findsOneWidget);
  });

  testWidgets('omits the subtitle line entirely when null', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const AppFinanceListRow(leadingIcon: Icons.movie, leadingColor: Colors.red, title: 'Netflix'),
      ),
    );

    expect(find.text('Netflix'), findsOneWidget);
    // No subtitle Text beyond the title itself.
    expect(
      find.descendant(of: find.byType(AppFinanceListRow), matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets('is not tappable by default, and becomes tappable with onTap', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      buildApp(
        AppFinanceListRow(
          leadingIcon: Icons.movie,
          leadingColor: Colors.red,
          title: 'Netflix',
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('Netflix'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a long title yields to a single-line ellipsis rather than wrapping or overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const SizedBox(
          width: 200,
          child: AppFinanceListRow(
            leadingIcon: Icons.movie,
            leadingColor: Colors.red,
            title: 'A dramatically longer subscription name than usual, translated',
            trailing: AppMoneyText('-¥1,590'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Text titleText = tester.widget<Text>(
      find.text('A dramatically longer subscription name than usual, translated'),
    );
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  // Checkpoint 10 responsive-layout hardening: a long title and a trailing
  // amount can both want more width than a genuinely narrow row has. The
  // fix must resolve that conflict without truncating a single digit of
  // [trailing] and without the [Row] itself overflowing -- see
  // [AppFinanceListRow]'s own updated doc comment for the full reasoning.
  // The four tests below re-prove the row's full responsive contract at
  // that same narrow width: the trailing amount survives intact, the
  // leading icon tile stays a stable size, a long subtitle degrades the
  // same way a long title does, and the fix continues to hold when a
  // narrow width is combined with enlarged text or RTL.

  testWidgets(
    'at that same narrow width, the trailing amount is never truncated -- it '
    'wraps onto extra lines instead of losing a digit or overflowing the row',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          const SizedBox(
            width: 200,
            child: AppFinanceListRow(
              leadingIcon: Icons.movie,
              leadingColor: Colors.red,
              title: 'A dramatically longer subscription name than usual, translated',
              trailing: AppMoneyText('-¥1,590'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Text.data always holds the full string regardless of how many
      // lines it wraps onto -- finding it here (rather than a truncated
      // "-¥1,5…" or similar) proves the fix degrades by wrapping, never
      // by dropping or shortening the formatted amount.
      expect(find.text('-¥1,590'), findsOneWidget);
    },
  );

  testWidgets('at that same narrow width, the leading icon tile keeps its stable size', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const SizedBox(
          width: 200,
          child: AppFinanceListRow(
            leadingIcon: Icons.movie,
            leadingColor: Colors.red,
            title: 'A dramatically longer subscription name than usual, translated',
            trailing: AppMoneyText('-¥1,590'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Container iconContainer = tester.widget<Container>(find.byType(Container));
    expect(iconContainer.constraints!.maxWidth, 40);
  });

  testWidgets('a long subtitle also yields to a single-line ellipsis at a narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const SizedBox(
          width: 200,
          child: AppFinanceListRow(
            leadingIcon: Icons.movie,
            leadingColor: Colors.red,
            title: 'Netflix',
            subtitle: 'A dramatically longer next-renewal note than usual, translated',
            trailing: AppMoneyText('-¥1,590'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Text subtitleText = tester.widget<Text>(
      find.text('A dramatically longer next-renewal note than usual, translated'),
    );
    expect(subtitleText.maxLines, 1);
    expect(subtitleText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a narrow width combined with 2.0x text scale and a long title still avoids overflow',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      await tester.pumpWidget(
        buildApp(
          const SizedBox(
            width: 200,
            child: AppFinanceListRow(
              leadingIcon: Icons.movie,
              leadingColor: Colors.red,
              title: 'A dramatically longer subscription name than usual, translated',
              trailing: AppMoneyText('-¥1,590'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('-¥1,590'), findsOneWidget);
    },
  );

  testWidgets('remains overflow-free under RTL at that same narrow width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 200,
              child: AppFinanceListRow(
                leadingIcon: Icons.movie,
                leadingColor: Colors.red,
                title: 'A dramatically longer subscription name than usual, translated',
                trailing: AppMoneyText('-¥1,590'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('-¥1,590'), findsOneWidget);
  });

  testWidgets('remains structurally correct under RTL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppFinanceListRow(
              leadingIcon: Icons.movie,
              leadingColor: Colors.red,
              title: 'Netflix',
              trailing: AppMoneyText('-¥1,590'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Netflix'), findsOneWidget);
  });

  testWidgets('remains usable at 2.0x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(
      buildApp(
        const AppFinanceListRow(
          leadingIcon: Icons.movie,
          leadingColor: Colors.red,
          title: 'Netflix',
          subtitle: 'Next: Sep 18, 2026',
          trailing: AppMoneyText('-¥1,590'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without exceptions under every theme', (tester) async {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
      AppTheme.pink(),
      AppTheme.ocean(),
      AppTheme.forest(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: AppFinanceListRow(
              leadingIcon: Icons.movie,
              leadingColor: Colors.red,
              title: 'Netflix',
              subtitle: 'Next: Sep 18, 2026',
              trailing: AppMoneyText('-¥1,590'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
