import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_occurrence_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/categories/presentation/category_identity_icon.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_history_screen.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_icon_asset.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Recurring UI Upgrade + History Views checkpoint, Cases 1 & 2.
// `RecurringHistoryScreen` has no outgoing navigation of its own (no
// `context.push`/`context.pop` anywhere in it -- see that file), so
// this harness is the simpler plain `MaterialApp(home: ...)` pattern
// `goal_detail_screen_test.dart` uses, not the real-`GoRouter` harness
// `account_detail_screen_test.dart`/`transaction_detail_screen_test.dart`
// need for their own Edit/Delete navigation.
//
// Seeds real `RecurringOccurrences` rows through the existing,
// already-tested `RecurringOccurrenceRepository.postOccurrence`/
// `skipOccurrence` -- never by inserting ad hoc rows -- so a posted
// row always carries a real linked `Transactions` row, exactly as
// production code produces one.

/// One-shot (non-reactive) equivalent of
/// `RecurringRuleRepository.watchActiveRules`/`watchAllRules`, built
/// against the identical filter predicate (see that repository's own
/// methods), for use ONLY from a `testWidgets` body that never pumps a
/// widget.
///
/// `RecurringRuleRepository.watchActiveRules(...).first` /
/// `.watchAllRules(...).first` hang forever there: Drift's `.watch()`
/// registers a `QueryStream` whose first value is delivered via a
/// batched zero-duration `Timer`, and `flutter_test`'s
/// `AutomatedTestWidgetsFlutterBinding` runs every `testWidgets` body
/// inside a `FakeAsync` zone where that `Timer` only fires once
/// something advances the fake clock -- normally a `tester.pump(...)`
/// call. A test that calls neither `pumpWidget` nor `pump` (a pure
/// repository-level check, like the one this helper serves) never
/// advances that clock, so the awaited `Future` never resolves and the
/// test stalls indefinitely with no pass/fail line. `tester.runAsync`
/// would also fix it (it runs the callback on the real, unfaked event
/// loop), but a plain one-shot query is simpler and matches this
/// project's existing convention for the same hang in
/// `budgets_screen_test.dart` (`readActiveOverallBudget`/
/// `readActiveCategoryBudget`) and `home_screen_test.dart` (its inline
/// one-shot account/category queries).
Future<List<RecurringRuleRow>> _readRulesOnce(
  AppDatabase db,
  String profileId, {
  required bool activeOnly,
}) {
  final query = db.select(db.recurringRules)
    ..where(
      (tbl) => activeOnly
          ? tbl.profileId.equals(profileId) & tbl.deletedAt.isNull()
          : tbl.profileId.equals(profileId),
    )
    ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
  return query.get();
}

void main() {
  Future<(AppDatabase, String, AccountRow)> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
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
    final AccountRepository accountRepo = AccountRepository(db);
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'JPY Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );
    final AccountRow account = await accountRepo.requireById(accountId);
    return (db, profileId, account);
  }

  Widget appWithHistory(
    ProviderContainer container, {
    String? ruleId,
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RecurringHistoryScreen(ruleId: ruleId),
      ),
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  group('Case 1 -- all-services year history (summary card tap)', () {
    testWidgets(
      'shows a posted and a skipped occurrence from different rules, each with the right '
      'icon, name, amount, date, and status treatment',
      (tester) async {
        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
          db,
          ruleRepo,
          TransactionRepository(db, accountRepo),
        );
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profileId,
          name: 'Entertainment',
          type: 'expense',
          icon: 'shopping',
        );
        final DateTime scheduled = DateTime.utc(DateTime.now().toUtc().year, 3, 10);

        final String netflixRuleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Netflix',
          amount: Money.fromMinorUnits(1590, 'JPY'),
          accountId: account.id,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
        );
        final String gymRuleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Gym',
          amount: Money.fromMinorUnits(8000, 'JPY'),
          accountId: account.id,
          categoryId: categoryId,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
        );

        await occurrenceRepo.postOccurrence(ruleId: netflixRuleId, scheduledDateUtc: scheduled);
        await occurrenceRepo.skipOccurrence(ruleId: gymRuleId, scheduledDateUtc: scheduled);

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container));
        await tester.pumpAndSettle();

        expect(find.text('Recurring history'), findsOneWidget);
        expect(find.byKey(const Key('recurringHistoryListView')), findsOneWidget);
        expect(find.text('Netflix'), findsOneWidget);
        expect(find.text('Gym'), findsOneWidget);
        expect(find.textContaining('¥1,590'), findsOneWidget);
        expect(find.textContaining('¥8,000'), findsOneWidget);
        expect(find.textContaining(DateFormat.yMMMd().format(scheduled)), findsNWidgets(2));

        // Service icon for the Netflix row (service > category > kind
        // precedence, same resolver as the main row).
        expect(
          find.image(const AssetImage('assets/icons/services/netflix.png')),
          findsOneWidget,
        );
        // Category icon for the Gym row (no service identity set).
        expect(find.byType(CategoryIdentityIcon), findsOneWidget);

        // Posted: the approved paid-stamp artwork plus a "Paid" status.
        expect(find.image(const AssetImage(RecurringIconAssets.paidStamp)), findsOneWidget);
        expect(find.text('Paid'), findsOneWidget);
        // Skipped: a muted glyph, never the paid stamp, plus "Skipped".
        expect(find.byIcon(Icons.block_outlined), findsOneWidget);
        expect(find.text('Skipped'), findsOneWidget);
      },
    );

    testWidgets(
      'a posted occurrence shows the real transaction amount, not the rule\'s current '
      'amount, if the rule was edited after posting',
      (tester) async {
        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
          db,
          ruleRepo,
          TransactionRepository(db, accountRepo),
        );
        final DateTime scheduled = DateTime.utc(DateTime.now().toUtc().year, 2, 1);
        final String ruleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Rent',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
        );
        await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: scheduled);

        // The rule's amount changes AFTER the historical post -- the
        // real transaction this occurrence created must stay the
        // authoritative, unchanged source for its displayed amount.
        await ruleRepo.updateRule(id: ruleId, amount: Money.fromMinorUnits(95000, 'JPY'));

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container));
        await tester.pumpAndSettle();

        expect(find.textContaining('¥80,000'), findsOneWidget);
        expect(find.textContaining('¥95,000'), findsNothing);
      },
    );

    testWidgets(
      'an occurrence scheduled last year is excluded from the current-year all-services view',
      (tester) async {
        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
          db,
          ruleRepo,
          TransactionRepository(db, accountRepo),
        );
        final int lastYear = DateTime.now().toUtc().year - 1;
        final DateTime scheduled = DateTime.utc(lastYear, 6, 1);
        final String ruleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Old Plan',
          amount: Money.fromMinorUnits(500, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
        );
        await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: scheduled);

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container));
        await tester.pumpAndSettle();

        expect(find.text('Old Plan'), findsNothing);
        expect(find.text('No history yet.'), findsOneWidget);
      },
    );

    testWidgets('shows the documented empty state when nothing has ever been posted or skipped',
        (tester) async {
      final (AppDatabase db, _, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHistory(container));
      await tester.pumpAndSettle();

      expect(find.text('No history yet.'), findsOneWidget);
      expect(find.byKey(const Key('recurringHistoryListView')), findsNothing);
    });

    testWidgets(
      'an expired (schedule ended, but NOT soft-deleted) rule\'s own handled occurrence still '
      'appears',
      (tester) async {
        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
          db,
          ruleRepo,
          TransactionRepository(db, accountRepo),
        );
        final int year = DateTime.now().toUtc().year;
        final DateTime scheduled = DateTime.utc(year, 1, 15);
        // A schedule that already ended (its own `endDate` is in the
        // past relative to "today") -- `isExpired`'s exact definition
        // on the main Recurring screen -- but the rule row itself was
        // never soft-deleted. `postOccurrence` has no schedule-bounds
        // check of its own (only an active-rule check), so this is a
        // faithful, real "already ended" rule with a real historical
        // posting, not a fabricated row.
        final String ruleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Old Gym Plan',
          amount: Money.fromMinorUnits(5000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
          endDate: DateTime.utc(year, 2, 1),
        );
        await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: scheduled);

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container));
        await tester.pumpAndSettle();

        expect(find.text('Old Gym Plan'), findsOneWidget);
        expect(find.textContaining('¥5,000'), findsOneWidget);
      },
    );

    testWidgets(
      'a soft-deleted rule\'s own handled occurrence still appears in the all-services year '
      'history -- Recurring History Final Corrections checkpoint',
      (tester) async {
        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
          db,
          ruleRepo,
          TransactionRepository(db, accountRepo),
        );
        final DateTime scheduled = DateTime.utc(DateTime.now().toUtc().year, 4, 1);
        final String ruleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Cancelled Gym',
          amount: Money.fromMinorUnits(6000, 'JPY'),
          accountId: account.id,
          serviceIdentityKey: 'spotify',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
        );
        await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: scheduled);

        // Soft-delete AFTER the historical posting -- `softDelete` only
        // ever touches `deletedAt`/`updatedAt` (see that method's own
        // doc comment), so `name`/`serviceIdentityKey`/`categoryId`/
        // `accountId` on this rule's row stay exactly what they were,
        // and this occurrence must still render with its real identity.
        await ruleRepo.softDelete(ruleId);

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container));
        await tester.pumpAndSettle();

        // Never hidden just because the rule is now gone from the
        // active Recurring list.
        expect(find.text('Cancelled Gym'), findsOneWidget);
        expect(find.textContaining('¥6,000'), findsOneWidget);
        // Its real service icon still resolves too -- a deleted rule's
        // own stored `serviceIdentityKey` is untouched by soft delete.
        expect(
          find.image(const AssetImage('assets/icons/services/spotify.png')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a soft-deleted rule never reappears in the active Recurring rule set, even though its '
      'history is preserved',
      (tester) async {
        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
        final String ruleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Cancelled Gym',
          amount: Money.fromMinorUnits(6000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.utc(DateTime.now().toUtc().year, 4, 1),
        );
        await ruleRepo.softDelete(ruleId);

        // `watchAllRules` (what Case 1 now reads) includes the deleted
        // row; `watchActiveRules` (what the main Recurring screen/Case
        // 2 still read) must not.
        //
        // Deliberately NOT `ruleRepo.watchActiveRules(...).first` /
        // `.watchAllRules(...).first` here -- see [_readRulesOnce]'s own
        // doc comment just above `seededDb` for why a bare
        // `.watch(...).first` hangs forever in a `testWidgets` body that
        // never pumps a widget (this test is a pure repository-level
        // check, exactly the case that hangs). Same fix as
        // `budgets_screen_test.dart`'s `readActiveOverallBudget` /
        // `home_screen_test.dart`'s inline one-shot queries: a one-shot
        // `.get()` that never registers a Drift `QueryStream`, built
        // against the identical filter predicate `watchActiveRules` /
        // `watchAllRules` use, so this test still proves the real
        // active-vs-all filtering contract.
        final List<RecurringRuleRow> active = await _readRulesOnce(db, profileId, activeOnly: true);
        final List<RecurringRuleRow> all = await _readRulesOnce(db, profileId, activeOnly: false);
        expect(active.where((RecurringRuleRow r) => r.id == ruleId), isEmpty);
        expect(all.where((RecurringRuleRow r) => r.id == ruleId), hasLength(1));
        await db.close();
      },
    );
  });

  group('Case 2 -- a single rule\'s own history (row tap)', () {
    testWidgets(
      'scopes strictly to the selected rule, excluding another rule\'s own handled occurrences',
      (tester) async {
        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
          db,
          ruleRepo,
          TransactionRepository(db, accountRepo),
        );
        final DateTime jan = DateTime.utc(DateTime.now().toUtc().year, 1, 15);
        final DateTime feb = DateTime.utc(DateTime.now().toUtc().year, 2, 15);
        final String netflixRuleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Netflix',
          amount: Money.fromMinorUnits(1590, 'JPY'),
          accountId: account.id,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: jan,
        );
        final String spotifyRuleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Spotify',
          amount: Money.fromMinorUnits(980, 'JPY'),
          accountId: account.id,
          serviceIdentityKey: 'spotify',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: jan,
        );
        await occurrenceRepo.postOccurrence(ruleId: netflixRuleId, scheduledDateUtc: jan);
        await occurrenceRepo.postOccurrence(ruleId: netflixRuleId, scheduledDateUtc: feb);
        await occurrenceRepo.postOccurrence(ruleId: spotifyRuleId, scheduledDateUtc: jan);

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container, ruleId: netflixRuleId));
        await tester.pumpAndSettle();

        expect(find.text('Netflix history'), findsOneWidget); // AppBar title
        expect(find.byKey(const Key('recurringHistoryListView')), findsOneWidget);
        expect(find.textContaining('¥1,590'), findsNWidgets(2)); // Netflix's two postings
        expect(find.textContaining('¥980'), findsNothing); // Spotify's posting excluded
        expect(
          find.image(const AssetImage('assets/icons/services/netflix.png')),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('shows the empty state for a rule with no handled occurrences yet',
        (tester) async {
      final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final String ruleId = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: account.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(2035, 1, 1),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHistory(container, ruleId: ruleId));
      await tester.pumpAndSettle();

      expect(find.text('Rent history'), findsOneWidget);
      expect(find.text('No history yet.'), findsOneWidget);
    });

    testWidgets(
      'falls back to the generic title and the empty state for an id that does not name any '
      'active rule',
      (tester) async {
        final (AppDatabase db, _, _) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container, ruleId: 'not-a-real-rule-id'));
        await tester.pumpAndSettle();

        expect(find.text('Recurring history'), findsOneWidget);
        expect(find.text('No history yet.'), findsOneWidget);
      },
    );
  });

  group('History row presentation', () {
    testWidgets('the paid-stamp artwork renders small, never enlarged into the main identity icon',
        (tester) async {
      final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
      final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
        db,
        ruleRepo,
        TransactionRepository(db, accountRepo),
      );
      final DateTime scheduled = DateTime.utc(DateTime.now().toUtc().year, 5, 1);
      final String ruleId = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Netflix',
        amount: Money.fromMinorUnits(1590, 'JPY'),
        accountId: account.id,
        serviceIdentityKey: 'netflix',
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: scheduled,
      );
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: scheduled);

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHistory(container));
      await tester.pumpAndSettle();

      final Finder stampFinder = find.image(const AssetImage(RecurringIconAssets.paidStamp));
      expect(stampFinder, findsOneWidget);
      final Image stamp = tester.widget<Image>(stampFinder);
      // Small status glyph, not the 28-34px scale the main identity
      // icon (service/category artwork) uses elsewhere in this row.
      expect(stamp.width, 16);
      expect(stamp.height, 16);
    });
  });

  for (final double width in <double>[320, 360, 390, 430]) {
    for (final double scale in <double>[1, 1.6]) {
      testWidgets('history screen renders without overflow at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 2400);
        // Every other responsive test in this codebase pairs
        // `physicalSize` with `devicePixelRatio = 1.0` on the very next
        // line (see e.g. `recurring_screen_test.dart`'s own identical
        // width/scale loop) -- this one was missing it. Without it the
        // test binding's own (non-1.0) default device pixel ratio
        // divides `width` down to a tiny logical width before layout
        // ever runs, which is what actually produced the "RenderFlex
        // overflowed" failures here, not a real production layout bug:
        // `width` logical pixels is the whole point of this loop.
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final (AppDatabase db, String profileId, AccountRow account) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final RecurringOccurrenceRepository occurrenceRepo = RecurringOccurrenceRepository(
          db,
          ruleRepo,
          TransactionRepository(db, accountRepo),
        );
        final DateTime scheduled = DateTime.utc(DateTime.now().toUtc().year, 5, 1);
        final String netflixRuleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Netflix',
          amount: Money.fromMinorUnits(1590, 'JPY'),
          accountId: account.id,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
        );
        final String gymRuleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Gym Membership With A Fairly Long Name',
          amount: Money.fromMinorUnits(800000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: scheduled,
        );
        await occurrenceRepo.postOccurrence(ruleId: netflixRuleId, scheduledDateUtc: scheduled);
        await occurrenceRepo.skipOccurrence(ruleId: gymRuleId, scheduledDateUtc: scheduled);

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHistory(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Service name: still visible in full for the short name
        // (`Netflix`); the long name only gets a single-line ellipsis
        // if it doesn't fit, never hidden -- `find.textContaining`
        // matches the full underlying string regardless.
        expect(find.text('Netflix'), findsOneWidget);
        expect(find.textContaining('Gym Membership'), findsOneWidget);
        // Amount: Recurring History Responsive Fix -- must remain
        // visible (never hidden/clipped) at every width/scale combo,
        // including the posted occurrence's real linked-transaction
        // amount and the skipped occurrence's rule amount.
        // `AppMoneyText` never truncates or ellipsizes (see its own
        // doc comment) -- at the one genuinely-too-narrow combination
        // this can soft-wrap onto a second line, but `find.textContaining`
        // still matches the full string either way.
        expect(find.textContaining('¥1,590'), findsOneWidget);
        expect(find.textContaining('¥800,000'), findsOneWidget);
        // Status: truthful posted/skipped status remains visible --
        // never hidden by the new width cap on the trailing column.
        expect(find.text('Paid'), findsOneWidget);
        expect(find.text('Skipped'), findsOneWidget);
        // Paid stamp: still the small 16x16 glyph, never enlarged to
        // compensate for the narrower trailing column -- same
        // assertion as "the paid-stamp artwork renders small..." above,
        // now also verified under every responsive width/scale combo.
        final Finder stampFinder = find.image(const AssetImage(RecurringIconAssets.paidStamp));
        expect(stampFinder, findsOneWidget);
        final Image stamp = tester.widget<Image>(stampFinder);
        expect(stamp.width, 16);
        expect(stamp.height, 16);
      });
    }
  }
}
