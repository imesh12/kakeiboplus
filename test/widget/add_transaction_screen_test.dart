import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/transactions/presentation/add_transaction_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  Future<AppDatabase> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final AccountRepository accountRepo = AccountRepository(db);
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
    await accountRepo.createAccount(
      profileId: profileId,
      name: 'JPY Wallet',
      type: 'cash',
      currencyCode: 'JPY',
      openingBalance: Money.fromMinorUnits(10000, 'JPY'),
    );
    await accountRepo.createAccount(
      profileId: profileId,
      name: 'LKR Wallet',
      type: 'cash',
      currencyCode: 'LKR',
    );
    return db;
  }

  /// Pushes [screen] on top of a placeholder home route so
  /// `Navigator.of(context).pop()` on save has somewhere to return to.
  Widget appWithPushedScreen(AppDatabase db, Widget screen) {
    return ProviderScope(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => screen),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'the destination dropdown for a transfer only offers accounts sharing '
      "the source account's currency (ADR-019, form-layer enforcement)", (tester) async {
    final AppDatabase db = await seededDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      appWithPushedScreen(db, const AddTransactionScreen(initialType: 'transfer')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Only one JPY account exists, and the LKR account is a different
    // currency — there is no eligible same-currency destination, so the
    // screen must show the "no other account" message rather than a
    // dropdown that could let the user pick the LKR account.
    expect(
      find.textContaining('No other JPY account to transfer to yet'),
      findsOneWidget,
    );
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'To account'), findsNothing);
  });

  testWidgets('an expense amount that is too precise for the account currency is rejected', (
    tester,
  ) async {
    final AppDatabase db = await seededDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      appWithPushedScreen(db, const AddTransactionScreen(initialType: 'expense')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The first account (JPY Wallet) is selected by default. Field order
    // in the form is: account dropdown, category dropdown, amount
    // (MoneyTextField's inner TextFormField), note — so the amount field
    // is the FIRST TextFormField in the tree, not the last (the note
    // field is last).
    await tester.enterText(find.byType(TextFormField).first, '12.50');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(find.textContaining('JPY allows at most 0 decimal digit'), findsOneWidget);
    final List<dynamic> rows = await db.select(db.transactions).get();
    expect(rows, isEmpty);
  });
}
