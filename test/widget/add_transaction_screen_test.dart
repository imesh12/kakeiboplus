import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/transactions/presentation/add_transaction_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
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

/// The Checkpoint 5 restyle (fixed-type header, bordered Account/Category
/// and Note/Date cards, extra section spacing) grew the form tall enough
/// that, in the default widget-test viewport, the Save button sits past
/// the ListView's lazily-built extent -- it is not merely off-screen, it
/// is not mounted into the tree at all yet, so `tester.ensureVisible`
/// cannot be used directly (it requires the target to already exist).
/// `scrollUntilVisible` is the correct tool for that: it drags the
/// nearest `Scrollable` in small steps and re-evaluates the finder after
/// each step -- which is what forces the lazy `ListView` to build (and
/// then reveal) the Save button -- before finishing with the same
/// `Scrollable.ensureVisible` `ensureVisible` itself uses.
///
/// `.first` on the scrollable finder is required, not cosmetic: this
/// Flutter version's `TextField`/`EditableText` builds its own internal
/// `Scrollable` for cursor scrolling, so plain `find.byType(Scrollable)`
/// matches the form's ListView *and* each TextFormField on it -- more
/// than one match makes `scrollUntilVisible` throw ("Bad state: Too many
/// elements") the moment it tries to resolve a single scrollable to
/// drag. The ListView's own Scrollable is built, and therefore appears
/// in the element tree, before the fields nested inside it, so `.first`
/// deterministically selects the ListView, never a field's.
Future<void> scrollToSaveButton(WidgetTester tester, {String label = 'Save'}) {
  return tester.scrollUntilVisible(
    find.widgetWithText(FilledButton, label),
    300,
    scrollable: find.byType(Scrollable).first,
  );
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
  // CP6.2 (Localization Phase 1): `AddTransactionScreen` now reads
  // `AppLocalizations.of(context)`, so every test app -- not just the new
  // Japanese-locale ones -- must wire
  // `AppLocalizations.localizationsDelegates`/`supportedLocales`, exactly
  // like `app_shell_test.dart` already does for CP6.1. `{Locale locale =
  // const Locale('en')}` keeps every pre-existing call site passing
  // (English is still the default), while the new Japanese-proof tests
  // pass `locale: const Locale('ja')`.
  Widget appWithPushedScreen(
    ProviderContainer container,
    Widget screen, {
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    await scrollToSaveButton(tester);
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

  // -- Checkpoint 5 (Transaction UX Phase B): Add/Edit form visual
  // polish -- header/badge/type, the transfer From -> To affordance, and
  // a smoke test that every existing control survived the restyle. None
  // of these duplicate the behavior already covered above; they cover
  // only what Checkpoint 5 itself added or could plausibly have broken.
  group('Checkpoint 5 visual polish', () {
    testWidgets('the Expense form header shows the fixed type as a badge and label', (
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

      // AppBar title is "Add expense" -- distinct from the header's
      // plain "Expense" label, so no duplication to account for here.
      expect(find.text('Expense'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('the Income form header shows the fixed type as a badge and label', (
      tester,
    ) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, const AddTransactionScreen(initialType: 'income')),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // AppBar title is "Add income" -- distinct from the header's
      // plain "Income" label.
      expect(find.text('Income'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('the Transfer form header shows the fixed type as a badge and label', (
      tester,
    ) async {
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

      // Unlike expense/income, the AppBar title for a new transfer is
      // itself "Transfer" (`_titleFor`, unchanged), so it legitimately
      // duplicates the header's "Transfer" label -- two widgets, not
      // one, per the test-discipline instruction to call this out.
      expect(find.text('Transfer'), findsNWidgets(2));
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets(
        'the Transfer form shows a From -> To visual affordance between the account and '
        'destination dropdowns, and destination filtering still only offers same-currency '
        'accounts', (tester) async {
      final AppDatabase db = await seededDb();
      final profile = await ProfileRepository(db).getProfile();
      await AccountRepository(db).createAccount(
        profileId: profile!.id,
        name: 'JPY Savings',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, const AddTransactionScreen(initialType: 'transfer')),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Decorative From -> To connector between the account and
      // destination dropdowns (Checkpoint 5, requirement D) -- purely
      // visual, adds no selector of its own.
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // Destination filtering (ADR-019) still works exactly as before: the
      // dropdown's own display string is unchanged by Checkpoint 5
      // ("Name (CURRENCY)"), and DropdownButtonFormField only renders an
      // item's text once it's either selected or the menu is open -- with
      // nothing selected yet, open it to confirm it offers the other
      // same-currency (JPY) account and correctly excludes the LKR one.
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'To account'), findsOneWidget);
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'To account'));
      await tester.pumpAndSettle();
      expect(find.text('JPY Savings (JPY)'), findsOneWidget);
      expect(find.text('LKR Wallet (LKR)'), findsNothing);
      await tester.tap(find.text('JPY Savings (JPY)'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'the account dropdown, category dropdown, amount field, note field, calendar icon, '
        'and Save button are all still present and usable after the Checkpoint 5 restyle',
        (tester) async {
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

      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'JPY Wallet (JPY)'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Category (optional)'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNWidgets(2)); // amount + note
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);

      // Save isn't mounted yet at this scroll position -- see
      // scrollToSaveButton's doc comment -- so the existence check below
      // has to come after scrolling, not before.
      await scrollToSaveButton(tester);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // Extra settle cycle: same Riverpod autoDispose -> Drift
      // StreamQueryStore.markAsClosed timer-drain gap documented on
      // disposeInOrder above, for this expense-type Save+pop with
      // categoriesForTypeProvider actively watched.
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget); // saved and popped successfully
    });
  });

  // -- Edit mode (Beta 1 Transaction UX, `docs/14_DECISION_LOG.md`
  // ADR-025, Phase A) -- AddTransactionScreen(existingTransaction: ...)
  // reuses every widget/validation path above; these tests cover what's
  // specific to editing: prefill, the three approved corrections
  // (currency re-derivation, transfer categoryId, and the
  // TransactionNotFoundException race), and time-of-day preservation on
  // a date change.

  group('edit mode', () {
    Future<(AppDatabase, String profileId, String jpyAccountId, String lkrAccountId)>
        seededEditDb() async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      final ProfileRepository profileRepo = ProfileRepository(db);
      final AccountRepository accountRepo = AccountRepository(db);
      await CategoryRepository(db).seedSystemCategoriesIfNeeded();
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
      final String jpyAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final String lkrAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'LKR Wallet',
        type: 'cash',
        currencyCode: 'LKR',
      );
      return (db, profileId, jpyAccountId, lkrAccountId);
    }

    Future<Transaction> transactionRow(AppDatabase db, String id) {
      return (db.select(db.transactions)..where((tbl) => tbl.id.equals(id))).getSingle();
    }

    testWidgets(
        'editing an existing expense prefills account, category, amount, note, and date, '
        'and saving persists the edited values', (tester) async {
      final (AppDatabase db, String profileId, String jpyAccountId, String lkrAccountId) =
          await seededEditDb();
      final TransactionRepository txRepo =
          TransactionRepository(db, AccountRepository(db));
      final DateTime originalOccurredAtUtc = DateTime.utc(2026, 3, 15, 8, 0);
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: jpyAccountId,
        amount: Money.fromMinorUnits(1200, 'JPY'),
        categoryId: 'sys-dining',
        note: 'Lunch',
        occurredAtUtc: originalOccurredAtUtc,
      );
      final Transaction existing = await transactionRow(db, txId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, AddTransactionScreen(existingTransaction: existing)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit expense'), findsOneWidget);
      expect(find.text('JPY Wallet (JPY)'), findsOneWidget);
      expect(find.text('Dining Out'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
        '1200',
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).last).initialValue,
        'Lunch',
      );
      final DateTime expectedLocal = originalOccurredAtUtc.toLocal();
      expect(
        find.text(
          '${expectedLocal.year}-${expectedLocal.month.toString().padLeft(2, '0')}-'
          '${expectedLocal.day.toString().padLeft(2, '0')}',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).first, '1500');
      await tester.enterText(find.byType(TextFormField).last, 'Lunch with client');
      await scrollToSaveButton(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // One extra settle cycle: Riverpod's autoDispose scheduler defers
      // disposing `categoriesForTypeProvider` (watched by this
      // expense/income form's `_CategoryDropdown`) to a later frame than
      // the one that completes this Save+pop, and that deferred dispose
      // is what drives Drift's `StreamQueryStore.markAsClosed` to
      // schedule its zero-duration `Timer` -- one settle can land right
      // on that boundary, so a second is needed to fully drain it before
      // `disposeInOrder` forces an unmount.
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget); // popped back
      final Transaction updated = await transactionRow(db, txId);
      expect(updated.amountMinorUnits, 1500);
      expect(updated.note, 'Lunch with client');
      expect(updated.type, 'expense'); // unchanged -- ADR-025
      expect(updated.id, txId); // same id preserved
    });

    testWidgets(
        "changing a transaction's date preserves its existing local time-of-day rather than "
        'collapsing it to midnight (Decision 3, ADR-025)', (tester) async {
      final (AppDatabase db, String profileId, String jpyAccountId, String _) =
          await seededEditDb();
      final TransactionRepository txRepo =
          TransactionRepository(db, AccountRepository(db));
      final DateTime originalOccurredAtUtc = DateTime.utc(2026, 3, 15, 8, 0);
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: jpyAccountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: originalOccurredAtUtc,
      );
      final Transaction existing = await transactionRow(db, txId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, AddTransactionScreen(existingTransaction: existing)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Opens the Material date picker, already on the transaction's own
      // month/year (`initialDate: _occurredAt`) -- pick a different day
      // in the same month so no month/year navigation is needed.
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await scrollToSaveButton(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // One extra settle cycle: same Riverpod autoDispose ->
      // Drift StreamQueryStore.markAsClosed timer-drain gap as the
      // currency-switch case above -- this is also an expense-type
      // Save+pop with `categoriesForTypeProvider` actively watched.
      await tester.pumpAndSettle();

      final Transaction updated = await transactionRow(db, txId);

      // Convert both the ORIGINAL persisted row and the EDITED row to
      // local using the same runtime timezone conversion the app itself
      // uses (`.toLocal()`) -- no hard-coded offset, so this holds
      // regardless of what timezone the test happens to run in.
      final DateTime originalLocal = existing.occurredAt.toLocal();
      final DateTime updatedLocal = updated.occurredAt.toLocal();

      // The calendar date changed as intended...
      expect(updatedLocal.year, originalLocal.year);
      expect(updatedLocal.month, originalLocal.month);
      expect(updatedLocal.day, 20);
      expect(updatedLocal.day, isNot(originalLocal.day));

      // ...while the local time-of-day was preserved exactly, on plain
      // integer fields -- immune to any DateTime tag/precision issue
      // (Decision 3, ADR-025).
      expect(updatedLocal.hour, originalLocal.hour);
      expect(updatedLocal.minute, originalLocal.minute);
      expect(updatedLocal.second, originalLocal.second);

      // Separately, since the exact resulting INSTANT is knowable (new
      // calendar date + old local time-of-day, converted by the same
      // runtime's own local<->UTC rule), confirm it with
      // `isAtSameMomentAs` -- the tag-agnostic comparison, unlike `==`,
      // which distinguishes UTC-tagged from local-tagged DateTimes even
      // when they denote the same moment (see
      // `docs/14_DECISION_LOG.md` ADR-025 Phase A RCA).
      final DateTime expectedInstant = DateTime(
        originalLocal.year,
        originalLocal.month,
        20,
        originalLocal.hour,
        originalLocal.minute,
        originalLocal.second,
      ).toUtc();
      expect(updated.occurredAt.isAtSameMomentAs(expectedInstant), isTrue);
    });

    testWidgets(
        'switching to a different-currency account while editing an expense re-parses the '
        'typed amount under the new currency rather than carrying over the old minor units '
        '(Correction 1, ADR-025)', (tester) async {
      final (AppDatabase db, String profileId, String jpyAccountId, String lkrAccountId) =
          await seededEditDb();
      final TransactionRepository txRepo =
          TransactionRepository(db, AccountRepository(db));
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: jpyAccountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction existing = await transactionRow(db, txId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, AddTransactionScreen(existingTransaction: existing)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'JPY Wallet (JPY)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LKR Wallet (LKR)').last);
      await tester.pumpAndSettle(); // lets MoneyTextField's post-frame re-parse run

      await scrollToSaveButton(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // One extra settle cycle: combining the currency-switch's
      // deferred `addPostFrameCallback` re-parse (see
      // money_text_field.dart's `didUpdateWidget`) with a real
      // Drift/Riverpod-backed screen and a completed Save+pop needs a
      // beat longer than the simpler cases in this file to fully drain
      // before `disposeInOrder` forces an unmount.
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget); // popped -- no error surfaced
      final Transaction updated = await transactionRow(db, txId);
      expect(updated.accountId, lkrAccountId);
      expect(updated.currencyCode, 'LKR');
      // '500' re-parsed under LKR's 2 decimal digits is 500.00 LKR (50000
      // minor units) -- NOT the old JPY minor-unit value (500) merely
      // relabeled as LKR, which is exactly the bug Correction 1 forbids.
      expect(updated.amountMinorUnits, 50000);
    });

    testWidgets(
        "editing a transfer's source account to a currency that no longer matches its "
        'destination surfaces a clear currency-mismatch error rather than silently '
        'transferring across currencies', (tester) async {
      final (AppDatabase db, String profileId, String jpyAccountId, String lkrAccountId) =
          await seededEditDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String jpySecondAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Savings',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
      final String txId = await txRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: jpyAccountId,
        destinationAccountId: jpySecondAccountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction existing = await transactionRow(db, txId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, AddTransactionScreen(existingTransaction: existing)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit transfer'), findsOneWidget);

      // Switch the source ("From account") to the LKR account. The
      // destination dropdown only ever *offers* same-currency accounts
      // (ADR-019), but this doesn't retroactively clear an
      // already-selected destination that's now a currency mismatch --
      // the repository's independent check is what actually protects
      // the invariant here, which is exactly what this test proves.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'JPY Wallet (JPY)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LKR Wallet (LKR)').last);
      await tester.pumpAndSettle();

      await scrollToSaveButton(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsNothing); // did NOT pop -- save was rejected
      expect(find.textContaining("doesn't match the selected account"), findsOneWidget);
      final Transaction unchanged = await transactionRow(db, txId);
      expect(unchanged.accountId, jpyAccountId); // nothing was persisted
      expect(unchanged.currencyCode, 'JPY');
    });

    testWidgets(
        'editing a transaction that was soft-deleted elsewhere in the meantime surfaces a '
        "clear 'no longer available' error rather than silently succeeding "
        '(TransactionNotFoundException, Correction 3)', (tester) async {
      final (AppDatabase db, String profileId, String jpyAccountId, String _) =
          await seededEditDb();
      final TransactionRepository txRepo =
          TransactionRepository(db, AccountRepository(db));
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: jpyAccountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction existing = await transactionRow(db, txId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, AddTransactionScreen(existingTransaction: existing)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Simulates the row disappearing out from under this open edit
      // screen -- e.g. deleted from the transaction detail screen in
      // another tab/window -- between opening the form and saving it.
      await txRepo.softDelete(txId);

      await tester.enterText(find.byType(TextFormField).first, '600');
      await scrollToSaveButton(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsNothing); // did NOT pop
      expect(find.textContaining('no longer available'), findsOneWidget);
    });

    testWidgets(
        'editing an existing transfer updates its amount and destination while keeping '
        'categoryId null and its type fixed to transfer', (tester) async {
      final (AppDatabase db, String profileId, String jpyAccountId, String _) =
          await seededEditDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String jpySecondAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Savings',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final String jpyThirdAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Emergency',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
      final String txId = await txRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: jpyAccountId,
        destinationAccountId: jpySecondAccountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction existing = await transactionRow(db, txId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, AddTransactionScreen(existingTransaction: existing)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'JPY Savings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY Emergency').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '750');
      await scrollToSaveButton(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget); // popped -- saved successfully
      final Transaction updated = await transactionRow(db, txId);
      expect(updated.type, 'transfer');
      expect(updated.destinationAccountId, jpyThirdAccountId);
      expect(updated.amountMinorUnits, 750);
      expect(updated.categoryId, isNull);
    });

    testWidgets(
        'edit mode presents the transaction type as a fixed, non-interactive label -- no '
        'type switcher of any kind appears in the header', (tester) async {
      final (AppDatabase db, String profileId, String jpyAccountId, String _) =
          await seededEditDb();
      final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
      final String txId = await txRepo.recordIncome(
        profileId: profileId,
        accountId: jpyAccountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction existing = await transactionRow(db, txId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(container, AddTransactionScreen(existingTransaction: existing)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit income'), findsOneWidget); // AppBar title
      expect(find.text('Income'), findsOneWidget); // header label, fixed type
      expect(find.byIcon(Icons.add), findsOneWidget); // TransactionIconBadge icon for income

      // No interactive type-switcher exists anywhere on the screen: no
      // segmented control, no choice chips, no type dropdown -- the
      // header is plain Text/Icon with no tap target of its own, and the
      // only DropdownButtonFormFields on screen are account + category.
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    });
  });

  // -- CP6.2 (Localization Phase 1): Full Add Transaction Form
  // Localization. Exercises the REAL `AddTransactionScreen` under the
  // Japanese locale (via `appWithPushedScreen`'s new `locale:` param) --
  // no fake/translated stand-in widgets, same pattern CP6.1 established
  // for `app_shell_test.dart`.
  group('CP6.2 Japanese localization', () {
    testWidgets(
        'A: the expense form renders its major labels in Japanese and Save '
        'remains usable end-to-end, with no exceptions', (tester) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(
          container,
          const AddTransactionScreen(initialType: 'expense'),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('支出を追加'), findsOneWidget); // AppBar title
      expect(find.text('支出'), findsOneWidget); // header label (fixed type)
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, '口座'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'カテゴリ（任意）'),
        findsOneWidget,
      );
      expect(find.text('日付'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.pump();
      await scrollToSaveButton(tester, label: '保存');
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(); // categoriesForTypeProvider autoDispose drain, as above

      expect(find.text('open'), findsOneWidget); // saved and popped successfully
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'B: the income form shows the correct Japanese transaction type and its '
        'core fields remain usable', (tester) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(
          container,
          const AddTransactionScreen(initialType: 'income'),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('収入を追加'), findsOneWidget); // AppBar title
      expect(find.text('収入'), findsOneWidget); // header label (fixed type)

      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.pump();
      await scrollToSaveButton(tester, label: '保存');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget); // saved and popped successfully
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'C: the transfer form shows 振替, localizes the source/destination '
        'fields, and same-currency filtering behavior is unchanged', (tester) async {
      // Same seeded shape as the top-level "destination dropdown ...
      // only offers accounts sharing the source account's currency"
      // test: exactly one JPY account and one LKR account, so there is
      // no eligible same-currency destination -- proving the fallback
      // message (and its localization) without tapping any dropdown
      // menu, which keeps this test independent of the known
      // transfer-dropdown tap warning elsewhere in this file.
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(
          container,
          const AddTransactionScreen(initialType: 'transfer'),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // AppBar title for add-mode transfer is itself "振替" (reusing the
      // same word as the header label), exactly like the English
      // "Transfer" case -- two widgets, not one.
      expect(find.text('振替'), findsNWidgets(2));
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, '振替元口座'),
        findsOneWidget,
      );
      // From -> To visual affordance still renders regardless of locale.
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      // No eligible same-currency destination -- ADR-019 form-layer
      // filtering unchanged -- so the localized fallback message shows
      // instead of a destination dropdown.
      expect(find.textContaining('他に振替可能なJPY口座がありません'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<String>, '振替先口座'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'D: choosing no destination on a transfer with an eligible destination '
        'surfaces the localized Japanese validation message', (tester) async {
      final AppDatabase db = await seededDb();
      // A second JPY account so a real destination dropdown renders
      // (eligible.isNotEmpty) instead of the C test's fallback message --
      // this exercises `_DestinationAccountDropdown`'s own `validator`
      // via `FormState.validate()`, a different code path from the
      // no-eligible-account case.
      final profile = await ProfileRepository(db).getProfile();
      await AccountRepository(db).createAccount(
        profileId: profile!.id,
        name: 'JPY Savings',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(
          container,
          const AddTransactionScreen(initialType: 'transfer'),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // A valid amount, but no destination account is ever selected.
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.pump();
      await scrollToSaveButton(tester, label: '保存');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsNothing); // did NOT pop -- save was rejected
      expect(find.text('振替先口座を選択してください。'), findsOneWidget);
      final List<dynamic> rows = await db.select(db.transactions).get();
      expect(rows, isEmpty);
    });

    testWidgets(
        'E1: the Japanese expense form has no overflow/render exceptions at 1.6x '
        'text scale, and the amount field and Save remain reachable', (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;

      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(
          container,
          const AddTransactionScreen(initialType: 'expense'),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byType(TextFormField).first, findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.pump();
      await scrollToSaveButton(tester, label: '保存');
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'E2: the Japanese transfer form has no overflow/render exceptions at 2.0x '
        'text scale, and the amount field and Save remain reachable', (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(
          container,
          const AddTransactionScreen(initialType: 'transfer'),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byType(TextFormField).first, findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.pump();
      await scrollToSaveButton(tester, label: '保存');
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'E3: the Japanese expense form has no overflow/render exceptions at a '
        'narrow 320px width combined with 1.6x text scale, and the amount field '
        'and Save remain reachable', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;

      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithPushedScreen(
          container,
          const AddTransactionScreen(initialType: 'expense'),
          locale: const Locale('ja'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byType(TextFormField).first, findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.pump();
      await scrollToSaveButton(tester, label: '保存');
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.7: locks in the Account/Category
  // section's and the Amount field's new bordered-card visual treatment
  // (`AppCard(bordered: true)`) via the same shape/side/color contract
  // `app_card_test.dart`/`goal_detail_screen_test.dart` (CP7.4) already
  // assert for `AppCard` -- never a pixel value. This screen is shared by
  // Add and Edit (see `AddTransactionScreen`'s own doc comment -- Edit
  // reaches it via `EditTransactionScreen`), so this test doubles as Edit
  // Transaction's own visual regression coverage; `edit_transaction_screen_
  // test.dart` deliberately does not re-test this screen's own rendering
  // (see that file's header comment).
  // -----------------------------------------------------------------------
  testWidgets(
      'CP7.7: the Account/Category section and the Amount field each render inside a '
      'bordered, near-white card matching the converged visual system', (tester) async {
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

    final BuildContext context = tester.element(find.byType(MoneyTextField));
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppTokens tokens = context.appTokens;

    void expectBorderedCard(Finder anchor) {
      final Card cardWidget = tester.widget<Card>(
        find.ancestor(of: anchor, matching: find.byType(Card)).first,
      );
      expect(cardWidget.color, colors.surface);
      expect(cardWidget.elevation, 0);
      final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);
    }

    // The account dropdown defaults to the first seeded account (JPY
    // Wallet) -- same display string ("Name (CURRENCY)") the account
    // dropdown's own existing tests already key off.
    expectBorderedCard(
      find.widgetWithText(DropdownButtonFormField<String>, 'JPY Wallet (JPY)'),
    );
    expectBorderedCard(find.byType(MoneyTextField));
  });
}
