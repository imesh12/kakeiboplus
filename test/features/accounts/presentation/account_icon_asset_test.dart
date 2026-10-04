import 'package:ai_financial_coach/features/accounts/presentation/account_icon_asset.dart';
import 'package:flutter_test/flutter_test.dart';

// Accounts Icon Pack Full Integration checkpoint: pure-function coverage
// for the centralized account-icon resolver, mirroring
// `category_icon_asset_test.dart`'s own style -- no widget pump needed.
// Supersedes `account_type_presentation_public_icon_test.dart` /
// `account_creation_kind_presentation_public_icon_test.dart`, which
// tested the two narrower, public-pool-only helpers this checkpoint
// removed.
void main() {
  group('accountTypeIconAsset (account-specific tier only)', () {
    test('resolves every type judged a confident match against the approved Accounts pack', () {
      const Map<String, String> expected = <String, String>{
        'cash': 'assets/icons/accounts/cash.png',
        'card': 'assets/icons/accounts/credit_card.png',
        'creditCard': 'assets/icons/accounts/credit_card.png',
        'wallet': 'assets/icons/accounts/wallet.png',
        'deposit': 'assets/icons/accounts/deposit.png',
        'savings': 'assets/icons/accounts/savings_account.png',
      };
      for (final MapEntry<String, String> entry in expected.entries) {
        expect(accountTypeIconAsset(entry.key), entry.value, reason: 'type: ${entry.key}');
      }
    });

    test('"bank" has no account-specific artwork in the approved pack -- returns null here '
        '(it still resolves through the public tier -- see accountIconAssetFor below)', () {
      expect(accountTypeIconAsset('bank'), isNull);
    });

    test('an unrecognized/legacy-review type returns null, never throws', () {
      for (final String type in <String>[
        'legacyCardNeedsReview',
        'legacyUnknownNeedsReview',
        'some_future_type',
        '',
      ]) {
        expect(accountTypeIconAsset(type), isNull, reason: 'type: $type');
      }
    });
  });

  group('accountIconAssetFor (account-specific -> public -> null ladder)', () {
    test('every account-specific match from accountTypeIconAsset passes through unchanged', () {
      const Map<String, String> expected = <String, String>{
        'cash': 'assets/icons/accounts/cash.png',
        'card': 'assets/icons/accounts/credit_card.png',
        'creditCard': 'assets/icons/accounts/credit_card.png',
        'wallet': 'assets/icons/accounts/wallet.png',
        'deposit': 'assets/icons/accounts/deposit.png',
        'savings': 'assets/icons/accounts/savings_account.png',
      };
      for (final MapEntry<String, String> entry in expected.entries) {
        expect(accountIconAssetFor(entry.key), entry.value, reason: 'type: ${entry.key}');
      }
    });

    test('"bank" falls through to the public pool\'s business-building.png', () {
      expect(accountIconAssetFor('bank'), 'assets/icons/public/business_building.png');
    });

    test('an unrecognized/legacy-review type falls back all the way to null -- the existing '
        'Material glyph renders, never a blank/broken image', () {
      for (final String type in <String>[
        'legacyCardNeedsReview',
        'legacyUnknownNeedsReview',
        'checking',
        '',
      ]) {
        expect(accountIconAssetFor(type), isNull, reason: 'type: $type');
      }
    });

    test('never returns a path under docs/design -- only copied production assets', () {
      for (final String type in <String>['cash', 'card', 'creditCard', 'wallet', 'deposit', 'savings', 'bank']) {
        final String? asset = accountIconAssetFor(type);
        expect(asset, isNotNull, reason: 'type: $type');
        expect(asset, isNot(contains('docs/design')), reason: 'type: $type');
        expect(asset, startsWith('assets/icons/'), reason: 'type: $type');
      }
    });
  });
}
