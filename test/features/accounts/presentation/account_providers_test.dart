import 'dart:async';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/finance/card_network.dart';
import 'package:ai_financial_coach/core/finance/payment_instrument_type.dart';
import 'package:ai_financial_coach/features/accounts/presentation/account_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Recurring UI Foundation Audit (Checkpoint 3): coverage for the new
// `paymentInstrumentsForAccountProvider` / `firstActivePaymentInstrumentFor`
// foundation pair added so the redesigned Recurring row (and any other
// future display) can resolve "which card pays from this account"
// through one shared, tested provider rather than each screen opening
// its own ad-hoc stream or guessing which instrument is canonical.
//
// [paymentInstrumentsForAccountProvider] is a plain (non-`AsyncValue`)
// `Provider.autoDispose.family` -- it already collapses the underlying
// stream's loading/error states to an empty list (see that provider's
// own doc comment) -- so this waits for the predicate directly on `T`,
// unlike `recurring_providers_test.dart`'s `_waitFor`, which waits on
// `AsyncValue<T>`.
Future<T> _waitFor<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
  bool Function(T) predicate,
) {
  final Completer<T> completer = Completer<T>();
  late final ProviderSubscription<T> sub;
  sub = container.listen(provider, (T? previous, T next) {
    if (predicate(next) && !completer.isCompleted) {
      completer.complete(next);
    }
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late PaymentInstrumentRepository instrumentRepo;
  late String profileId;
  late String accountId;
  late String otherAccountId;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    instrumentRepo = PaymentInstrumentRepository(db, accountRepo);

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
    accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'ABC Visa',
      type: 'card',
      currencyCode: 'JPY',
    );
    otherAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Cash Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );

    container = ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test('an account with no payment instrument resolves to an empty list, never fabricated',
      () async {
    final List<PaymentInstrumentRow> instruments = await _waitFor(
      container,
      paymentInstrumentsForAccountProvider(otherAccountId),
      (List<PaymentInstrumentRow> list) => true,
    );
    expect(instruments, isEmpty);
    expect(firstActivePaymentInstrumentFor(instruments), isNull);
  });

  test('a single active instrument is resolved by both the list and the single-instrument selector',
      () async {
    await instrumentRepo.createInstrument(
      profileId: profileId,
      accountId: accountId,
      instrumentType: PaymentInstrumentType.debitCard,
      nickname: 'ABC Visa',
      network: CardNetwork.visa,
      last4: '4586',
    );

    final List<PaymentInstrumentRow> instruments = await _waitFor(
      container,
      paymentInstrumentsForAccountProvider(accountId),
      (List<PaymentInstrumentRow> list) => list.isNotEmpty,
    );
    expect(instruments, hasLength(1));
    expect(instruments.single.last4, '4586');
    expect(instruments.single.network, CardNetwork.visa.storageValue);

    final PaymentInstrumentRow? resolved = firstActivePaymentInstrumentFor(instruments);
    expect(resolved, isNotNull);
    expect(resolved!.last4, '4586');
  });

  test('two active instruments resolve to the oldest-created one, never guessed', () async {
    final String firstId = await instrumentRepo.createInstrument(
      profileId: profileId,
      accountId: accountId,
      instrumentType: PaymentInstrumentType.debitCard,
      nickname: 'Older card',
      network: CardNetwork.visa,
      last4: '1111',
    );
    await instrumentRepo.createInstrument(
      profileId: profileId,
      accountId: accountId,
      instrumentType: PaymentInstrumentType.debitCard,
      nickname: 'Newer card',
      network: CardNetwork.mastercard,
      last4: '2222',
    );

    final List<PaymentInstrumentRow> instruments = await _waitFor(
      container,
      paymentInstrumentsForAccountProvider(accountId),
      (List<PaymentInstrumentRow> list) => list.length == 2,
    );

    final PaymentInstrumentRow? resolved = firstActivePaymentInstrumentFor(instruments);
    expect(resolved, isNotNull);
    expect(resolved!.id, firstId);
    expect(resolved.last4, '1111');
  });

  test("resolving one account never surfaces another account's instrument", () async {
    await instrumentRepo.createInstrument(
      profileId: profileId,
      accountId: accountId,
      instrumentType: PaymentInstrumentType.debitCard,
      nickname: 'ABC Visa',
      network: CardNetwork.visa,
      last4: '4586',
    );
    // Give the write a moment to land before asserting the OTHER
    // account's stream stays empty, exactly like
    // `recurring_providers_test.dart`'s sibling-isolation tests.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final List<PaymentInstrumentRow> otherInstruments =
        container.read(paymentInstrumentsForAccountProvider(otherAccountId));
    expect(otherInstruments, isEmpty);
  });

  test('an archived (soft-deleted) instrument is excluded, never silently resurfaced', () async {
    final String instrumentId = await instrumentRepo.createInstrument(
      profileId: profileId,
      accountId: accountId,
      instrumentType: PaymentInstrumentType.debitCard,
      nickname: 'ABC Visa',
      network: CardNetwork.visa,
      last4: '4586',
    );
    await _waitFor(
      container,
      paymentInstrumentsForAccountProvider(accountId),
      (List<PaymentInstrumentRow> list) => list.isNotEmpty,
    );
    await instrumentRepo.softDelete(instrumentId);

    final List<PaymentInstrumentRow> instruments = await _waitFor(
      container,
      paymentInstrumentsForAccountProvider(accountId),
      (List<PaymentInstrumentRow> list) => list.isEmpty,
    );
    expect(instruments, isEmpty);
    expect(firstActivePaymentInstrumentFor(instruments), isNull);
  });
}
