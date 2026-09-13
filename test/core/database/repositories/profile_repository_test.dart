import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// International / Localization Foundation Checkpoint 3A: covers
// `ProfileRepository.updateInternationalPreferences` (the new atomic
// 8-field update) and reconfirms `createProfile`'s existing round-trip
// behavior for those same 8 fields. Deliberately does NOT cover any UI
// -- that's Checkpoint 3B.
void main() {
  // Scoped to its own group -- rather than declared directly under
  // `main()` -- for the same reason `budget_repository_test.dart` does
  // this: its setUp/tearDown, and the single shared in-memory `db` they
  // open per test, must never overlap with the "Persistence survives a
  // database reload" group below, which manages its own on-disk
  // AppDatabase instances one at a time.
  group('In-memory repository behavior', () {
    late AppDatabase db;
    late ProfileRepository profileRepo;
    late AccountRepository accountRepo;
    late TransactionRepository txRepo;
    late String profileId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      profileRepo = ProfileRepository(db);
      accountRepo = AccountRepository(db);
      txRepo = TransactionRepository(db, accountRepo);

      profileId = await profileRepo.createProfile(
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
    });

    tearDown(() async {
      await db.close();
    });

    test('createProfile round-trips all 8 international fields exactly', () async {
      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.homeCountry, 'LK');
      expect(profile.currentCountry, 'JP');
      expect(profile.homeCurrency, 'LKR');
      expect(profile.livingCurrency, 'JPY');
      expect(profile.preferredLanguage, 'en');
      expect(profile.timezone, 'Asia/Tokyo');
      expect(profile.dateFormat, 'yyyy-MM-dd');
      expect(profile.numberFormat, '#,##0.##');
    });

    test('updateInternationalPreferences updates all 8 values atomically', () async {
      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'US',
        currentCountry: 'CA',
        homeCurrency: 'USD',
        livingCurrency: 'CAD',
        preferredLanguage: 'ja',
        timezone: 'America/Toronto',
        dateFormat: 'dmy',
        numberFormat: 'period_comma',
      );

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.homeCountry, 'US');
      expect(profile.currentCountry, 'CA');
      expect(profile.homeCurrency, 'USD');
      expect(profile.livingCurrency, 'CAD');
      expect(profile.preferredLanguage, 'ja');
      expect(profile.timezone, 'America/Toronto');
      expect(profile.dateFormat, 'dmy');
      expect(profile.numberFormat, 'period_comma');
    });

    test('updateInternationalPreferences does not change displayName', () async {
      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'US',
        currentCountry: 'CA',
        homeCurrency: 'USD',
        livingCurrency: 'CAD',
        preferredLanguage: 'ja',
        timezone: 'America/Toronto',
        dateFormat: 'dmy',
        numberFormat: 'period_comma',
      );

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.displayName, 'Test User');
    });

    test('updateInternationalPreferences advances updatedAt without regressing it -- no brittle '
        'exact-timing assertion, just "did not go backwards"', () async {
      final ProfileRow before = (await profileRepo.getProfile())!;

      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'US',
        currentCountry: 'CA',
        homeCurrency: 'USD',
        livingCurrency: 'CAD',
        preferredLanguage: 'ja',
        timezone: 'America/Toronto',
        dateFormat: 'dmy',
        numberFormat: 'period_comma',
      );

      final ProfileRow after = (await profileRepo.getProfile())!;
      expect(after.updatedAt.isBefore(before.updatedAt), isFalse);
    });

    test('unknown/raw strings round-trip unchanged through repository reads -- the repository '
        'never normalizes or rewrites values it is given', () async {
      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'ZZ', // not in CountryRegistry
        currentCountry: 'QQ', // not in CountryRegistry
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'xx', // not in AppLanguageRegistry
        timezone: 'Not/AZone', // not in TimezoneRegistry
        dateFormat: 'totally-corrupt-format', // not in DateFormatRegistry
        numberFormat: 'totally-corrupt-format', // not in NumberFormatRegistry
      );

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.homeCountry, 'ZZ');
      expect(profile.currentCountry, 'QQ');
      expect(profile.preferredLanguage, 'xx');
      expect(profile.timezone, 'Not/AZone');
      expect(profile.dateFormat, 'totally-corrupt-format');
      expect(profile.numberFormat, 'totally-corrupt-format');
    });

    test('legacy raw date_format "yyyy-MM-dd" persists unchanged until explicitly updated', () async {
      // setUp already persisted the legacy raw value -- confirm nothing
      // (not createProfile, not a stray read) has silently rewritten it.
      ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.dateFormat, 'yyyy-MM-dd');

      // Reading again changes nothing.
      profile = await profileRepo.getProfile();
      expect(profile!.dateFormat, 'yyyy-MM-dd');

      // Only an explicit update changes it.
      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'en',
        timezone: 'Asia/Tokyo',
        dateFormat: 'ymd',
        numberFormat: '#,##0.##',
      );
      profile = await profileRepo.getProfile();
      expect(profile!.dateFormat, 'ymd');
    });

    test('legacy raw number_format "#,##0.##" persists unchanged until explicitly updated', () async {
      ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.numberFormat, '#,##0.##');

      profile = await profileRepo.getProfile();
      expect(profile!.numberFormat, '#,##0.##');

      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'en',
        timezone: 'Asia/Tokyo',
        dateFormat: 'yyyy-MM-dd',
        numberFormat: 'comma_period',
      );
      profile = await profileRepo.getProfile();
      expect(profile!.numberFormat, 'comma_period');
    });

    test('updating international preferences does not modify an existing transaction row or '
        'amount', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(128000, 'JPY'), // ¥128,000
        occurredAtUtc: DateTime.now().toUtc(),
      );

      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'US',
        currentCountry: 'CA',
        homeCurrency: 'USD',
        livingCurrency: 'CAD',
        preferredLanguage: 'ja',
        timezone: 'America/Toronto',
        dateFormat: 'dmy',
        numberFormat: 'period_comma',
      );

      final Transaction? tx = await txRepo.watchById(txId).first;
      expect(tx, isNotNull);
      expect(tx!.amountMinorUnits, 128000);
      expect(tx.currencyCode, 'JPY');
      expect(tx.type, 'expense');
    });

    test('updating profile currencies does not rewrite an existing transaction\'s own currency '
        'or amount -- a transaction\'s currency comes from its account, independent of the '
        'profile\'s home/living currency', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Kuwait Wallet',
        type: 'cash',
        currencyCode: 'KWD',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(987654, 'KWD'), // 987.654 KWD
        occurredAtUtc: DateTime.now().toUtc(),
      );

      // Change home/living currency to something entirely unrelated to
      // the account/transaction's own currency.
      await profileRepo.updateInternationalPreferences(
        profileId: profileId,
        homeCountry: 'US',
        currentCountry: 'US',
        homeCurrency: 'USD',
        livingCurrency: 'USD',
        preferredLanguage: 'en',
        timezone: 'America/New_York',
        dateFormat: 'mdy',
        numberFormat: 'comma_period',
      );

      final Transaction? tx = await txRepo.watchById(txId).first;
      expect(tx, isNotNull);
      expect(tx!.currencyCode, 'KWD');
      expect(tx.amountMinorUnits, 987654);

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.homeCurrency, 'USD');
      expect(profile.livingCurrency, 'USD');
    });

    // -----------------------------------------------------------------
    // Checkpoint 8.1 (Premium Theme Personalization Foundation):
    // updateThemePreference and the theme_preference column's own
    // default.
    // -----------------------------------------------------------------

    test('a freshly-created profile defaults theme_preference to "light" -- the schema column '
        'default, matching AppThemeStyle.fallback exactly', () async {
      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.themePreference, 'light');
    });

    test('updateThemePreference persists the given raw string exactly', () async {
      await profileRepo.updateThemePreference(profileId: profileId, themePreference: 'forest');

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.themePreference, 'forest');
    });

    test('updateThemePreference does not touch any other column', () async {
      await profileRepo.updateThemePreference(profileId: profileId, themePreference: 'ocean');

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.displayName, 'Test User');
      expect(profile.homeCountry, 'LK');
      expect(profile.currentCountry, 'JP');
      expect(profile.homeCurrency, 'LKR');
      expect(profile.livingCurrency, 'JPY');
      expect(profile.preferredLanguage, 'en');
      expect(profile.timezone, 'Asia/Tokyo');
      expect(profile.dateFormat, 'yyyy-MM-dd');
      expect(profile.numberFormat, '#,##0.##');
    });

    test('updateThemePreference advances updatedAt without regressing it', () async {
      final ProfileRow before = (await profileRepo.getProfile())!;

      await profileRepo.updateThemePreference(profileId: profileId, themePreference: 'pink');

      final ProfileRow after = (await profileRepo.getProfile())!;
      expect(after.updatedAt.isBefore(before.updatedAt), isFalse);
    });

    test('an unrecognized theme_preference string round-trips unchanged -- this repository '
        'never validates against AppThemeStyle, exactly like it never validates the other '
        'preference fields against their own registries', () async {
      await profileRepo.updateThemePreference(
        profileId: profileId,
        themePreference: 'not-a-real-theme',
      );

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.themePreference, 'not-a-real-theme');
    });

    test('updating the theme preference does not modify an existing transaction row or amount',
        () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(50000, 'JPY'),
        occurredAtUtc: DateTime.now().toUtc(),
      );

      await profileRepo.updateThemePreference(profileId: profileId, themePreference: 'dark');

      final Transaction? tx = await txRepo.watchById(txId).first;
      expect(tx, isNotNull);
      expect(tx!.amountMinorUnits, 50000);
      expect(tx.currencyCode, 'JPY');
      expect(tx.type, 'expense');
    });
  });

  group('Persistence survives a database reload', () {
    test('international preferences set via updateInternationalPreferences are still readable '
        'through a newly-opened AppDatabase/ProfileRepository against the same on-disk file',
        () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_profile_persistence_test_');
      final File dbFile = File('${tempDir.path}/test.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      // --- "First app launch": write through one AppDatabase instance ---
      AppDatabase fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      ProfileRepository fileProfileRepo = ProfileRepository(fileDb);
      final String fileProfileId = await fileProfileRepo.createProfile(
        displayName: 'Restart Test User',
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'en',
        timezone: 'Asia/Tokyo',
        dateFormat: 'yyyy-MM-dd',
        numberFormat: '#,##0.##',
      );
      await fileProfileRepo.updateInternationalPreferences(
        profileId: fileProfileId,
        homeCountry: 'US',
        currentCountry: 'CA',
        homeCurrency: 'USD',
        livingCurrency: 'CAD',
        preferredLanguage: 'ja',
        timezone: 'America/Toronto',
        dateFormat: 'dmy',
        numberFormat: 'period_comma',
      );

      // --- "App restart": fully close, then open a fresh AppDatabase and
      // a fresh ProfileRepository against the same file ---
      await fileDb.close();
      fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      fileProfileRepo = ProfileRepository(fileDb);

      final ProfileRow? profile = await fileProfileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.homeCountry, 'US');
      expect(profile.currentCountry, 'CA');
      expect(profile.homeCurrency, 'USD');
      expect(profile.livingCurrency, 'CAD');
      expect(profile.preferredLanguage, 'ja');
      expect(profile.timezone, 'America/Toronto');
      expect(profile.dateFormat, 'dmy');
      expect(profile.numberFormat, 'period_comma');
      expect(profile.displayName, 'Restart Test User');

      await fileDb.close();
    });

    test('a theme preference set via updateThemePreference is still readable through a '
        'newly-opened AppDatabase/ProfileRepository against the same on-disk file', () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_theme_persistence_test_');
      final File dbFile = File('${tempDir.path}/test.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      AppDatabase fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      ProfileRepository fileProfileRepo = ProfileRepository(fileDb);
      final String fileProfileId = await fileProfileRepo.createProfile(
        displayName: 'Restart Test User',
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'en',
        timezone: 'Asia/Tokyo',
        dateFormat: 'yyyy-MM-dd',
        numberFormat: '#,##0.##',
      );
      await fileProfileRepo.updateThemePreference(
        profileId: fileProfileId,
        themePreference: 'ocean',
      );

      await fileDb.close();
      fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      fileProfileRepo = ProfileRepository(fileDb);

      final ProfileRow? profile = await fileProfileRepo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.themePreference, 'ocean');

      await fileDb.close();
    });
  });
}
