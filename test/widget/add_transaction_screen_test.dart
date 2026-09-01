import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/transactions/presentation/add_transaction_screen.dart';
import 'package:ai_financial_coach/shared/widgets/money_text_field.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

/// Minimal harness reproducing the exact wiring `AddTransactionScreen` uses
/// between its account selection and `MoneyTextField`:
/// `MoneyTextField(currencyCode: ..., onParsed: (m) => setState(() => ...))`,
/// where the `currencyCode` passed in changes as a result of this widget's
/// own `setState()` (mirroring the account dropdown's `onChanged`).
///
/// This is deliberately independent of Drift, Riverpod, `AppDatabase`, and
/// `Navigator` — none of those are part of the bug's causal chain. The bug
/// lives entirely in the interaction between `MoneyTextField.didUpdateWidget`
/// and whatever ancestor `State` it calls `onParsed` on; reproducing it only
/// requires *an* ancestor with that wiring, not the real screen.
class _CurrencySwitchHarness extends StatefulWidget {
  const _CurrencySwitchHarness({required this.onAmountChanged});

  final ValueChanged<Money?> onAmountChanged;

  @override
  State<_CurrencySwitchHarness> createState() => _CurrencySwitchHarnessState();
}

class _CurrencySwitchHarnessState extends State<_CurrencySwitchHarness> {
  String _currencyCode = 'JPY';
  Money? _amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MoneyTextField(
          currencyCode: _currencyCode,
          onParsed: (Money? amount) => setState(() {
            _amount = amount;
            widget.onAmountChanged(_amount);
          }),
        ),
        TextButton(
          // Same shape as AddTransactionScreen's account dropdown
          // `onChanged`: a user action calls setState() to change which
          // currency is selected, which is what drives MoneyTextField's
          // currencyCode to change on the very next build.
          onPressed: () => setState(() => _currencyCode = 'LKR'),
          child: const Text('switch to LKR'),
        ),
      ],
    );
  }
}

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
  ///
  /// Takes an explicit [container] via [UncontrolledProviderScope] rather
  /// than letting a plain `ProviderScope` create and own one implicitly, so
  /// the test can dispose the container itself, on its own line, at a
  /// moment it controls. There's no GoRouter and no nested `ProviderScope`
  /// in this tree, so this one container is the only thing holding
  /// `accountsProvider` / `activeProfileProvider`'s live Drift query
  /// subscriptions.
  Widget appWithPushedScreen(ProviderContainer container, Widget screen) {
    return UncontrolledProviderScope(
      container: container,
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

  /// Deterministic shutdown for the two tests below that mount the real
  /// `AddTransactionScreen` over a live [container]/[db]. Neither of them
  /// ever taps Save successfully (one never taps Save at all; the other's
  /// Save attempt fails validation before any write happens), so neither
  /// causes a provider listener to drop before teardown starts — unmount,
  /// then dispose, then one `pumpAndSettle()` is sufficient to fire
  /// Drift's `StreamQueryStore.markAsClosed` `Timer.zero` from the
  /// resulting `StreamSubscription.cancel()` calls. (`tester.pump()` with
  /// no duration argument would NOT do this — it never calls
  /// `FakeAsync.elapse()`, so a Dart `Timer` scheduled at any duration,
  /// including zero, never gets invoked.)
  Future<void> disposeInOrder(
    WidgetTester tester,
    ProviderContainer container,
    AppDatabase db,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets(
      'the destination dropdown for a transfer only offers accounts sharing '
      "the source account's currency (ADR-019, form-layer enforcement)", (tester) async {
    final AppDatabase db = await seededDb();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(
      appWithPushedScreen(container, const AddTransactionScreen(initialType: 'transfer')),
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
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(
      appWithPushedScreen(container, const AddTransactionScreen(initialType: 'expense')),
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

  testWidgets(
      'switching the currency an ancestor passes to MoneyTextField while '
      'text is entered does not throw setState-during-build '
      '(regression: MoneyTextField.didUpdateWidget)', (tester) async {
    Money? lastParsed;

    // No AppDatabase, no ProviderContainer, no Navigator — deliberately.
    // See the class doc on _CurrencySwitchHarness for why none of that
    // machinery is needed to reproduce or prove the fix for this bug.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: _CurrencySwitchHarness(onAmountChanged: (m) => lastParsed = m),
          ),
        ),
      ),
    );

    // Valid under both JPY (0 decimals) and LKR (2 decimals), so the
    // currency switch below re-validates successfully rather than failing
    // for an unrelated reason.
    await tester.enterText(find.byType(TextFormField), '10');
    await tester.pump();
    expect(lastParsed, Money.fromMinorUnits(10, 'JPY'));

    // This is the exact mechanism that crashed in production:
    // AddTransactionScreen's account dropdown calling setState() to
    // change which account (and therefore currency) is selected, while
    // the amount field still holds text entered under the old currency.
    // Tapping this button calls the harness's own setState() the same
    // way -> its build() passes a new `currencyCode` to `MoneyTextField`
    // -> Flutter calls `MoneyTextField.didUpdateWidget()` as part of that
    // SAME build pass -> before the fix, that synchronously called
    // `onParsed()`, which called `setState()` on this still-mid-build
    // harness, throwing "setState() or markNeedsBuild() called during
    // build."
    await tester.tap(find.text('switch to LKR'));
    await tester.pump();

    expect(tester.takeException(), isNull);

    // Not just "didn't crash": the amount was actually re-validated
    // against the new currency. '10' parses to 10 minor units under JPY
    // (0 decimals) but 1000 minor units under LKR (2 decimals) — if
    // didUpdateWidget's deferred re-validation never ran, lastParsed
    // would still be the stale JPY-denominated value.
    expect(lastParsed, Money.fromMinorUnits(1000, 'LKR'));
  });
}
