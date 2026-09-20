import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/finance/legacy_account_classification.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint B (schema v9): pure, database-free tests for the exact
// legacy `Accounts.type` -> `balanceClass`/`subtype` mapping frozen by
// docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md §13.1. This is the
// SAME mapping `AccountRepository.createAccount` uses (see
// `account_repository_test.dart`'s "createAccount — classification"
// group for the through-the-repository equivalent of these cases) and
// that schema v9's migration backfills existing rows with (see
// `financial_account_classification_migration_test.dart`).
void main() {
  group('classifyLegacyAccountType', () {
    test("'cash' -> asset/cash", () {
      final result = classifyLegacyAccountType('cash');
      expect(result.balanceClass, BalanceClass.asset);
      expect(result.subtype, FinancialAccountSubtype.cash);
    });

    test("'bank' -> asset/bank — never guessed as checking/savings", () {
      final result = classifyLegacyAccountType('bank');
      expect(result.balanceClass, BalanceClass.asset);
      expect(result.subtype, FinancialAccountSubtype.bank);
    });

    test("'wallet' -> asset/wallet", () {
      final result = classifyLegacyAccountType('wallet');
      expect(result.balanceClass, BalanceClass.asset);
      expect(result.subtype, FinancialAccountSubtype.wallet);
    });

    test("'card' -> asset/legacyCardNeedsReview — never a liability", () {
      final result = classifyLegacyAccountType('card');
      expect(result.balanceClass, BalanceClass.asset);
      expect(result.balanceClass, isNot(BalanceClass.liability));
      expect(result.subtype, FinancialAccountSubtype.legacyCardNeedsReview);
    });

    test('an unrecognized type string -> asset/legacyUnknownNeedsReview, never guessed', () {
      final result = classifyLegacyAccountType('crypto');
      expect(result.balanceClass, BalanceClass.asset);
      expect(result.subtype, FinancialAccountSubtype.legacyUnknownNeedsReview);
    });

    test('an empty string -> asset/legacyUnknownNeedsReview', () {
      final result = classifyLegacyAccountType('');
      expect(result.balanceClass, BalanceClass.asset);
      expect(result.subtype, FinancialAccountSubtype.legacyUnknownNeedsReview);
    });
  });

  group('BalanceClass.fromStorageValue', () {
    test('round-trips both known values', () {
      expect(BalanceClass.fromStorageValue('asset'), BalanceClass.asset);
      expect(BalanceClass.fromStorageValue('liability'), BalanceClass.liability);
    });

    test('an unrecognized/corrupt value never throws and falls back to asset', () {
      expect(BalanceClass.fromStorageValue('garbage'), BalanceClass.asset);
    });
  });

  group('FinancialAccountSubtype.fromStorageValue', () {
    test('round-trips every currently-defined value', () {
      for (final subtype in FinancialAccountSubtype.values) {
        expect(FinancialAccountSubtype.fromStorageValue(subtype.storageValue), subtype);
      }
    });

    test('an unrecognized/corrupt value never throws and falls back to legacyUnknownNeedsReview', () {
      expect(
        FinancialAccountSubtype.fromStorageValue('garbage'),
        FinancialAccountSubtype.legacyUnknownNeedsReview,
      );
    });
  });
}
