import 'package:ai_financial_coach/shared/icons/public_icon_asset.dart';
import 'package:flutter_test/flutter_test.dart';

// Public Icons Pool Integration checkpoint: pure-function coverage for
// the generic public-icon resolver, mirroring
// `category_icon_asset_test.dart`'s own style for a resolver of this
// shape -- no widget pump needed.
void main() {
  group('publicIconAssetFor', () {
    test('resolves every mapped semantic key to its expected production asset path', () {
      const Map<PublicIconKey, String> expected = <PublicIconKey, String>{
        PublicIconKey.cash: 'assets/icons/public/cash_in_hand.png',
        PublicIconKey.bank: 'assets/icons/public/business_building.png',
      };
      for (final MapEntry<PublicIconKey, String> entry in expected.entries) {
        expect(publicIconAssetFor(entry.key), entry.value, reason: 'key: ${entry.key}');
      }
    });

    test('never returns a path under docs/design -- only the copied production asset', () {
      for (final PublicIconKey key in PublicIconKey.values) {
        final String? asset = publicIconAssetFor(key);
        expect(asset, isNotNull, reason: 'key: $key');
        expect(asset, isNot(contains('docs/design')), reason: 'key: $key');
        expect(asset, startsWith('assets/icons/public/'), reason: 'key: $key');
      }
    });
  });
}
