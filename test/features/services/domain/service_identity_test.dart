import 'package:ai_financial_coach/features/services/domain/service_identity.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
// Foundation): the service/subscription identity catalog is a SEPARATE
// concept from category identity -- proven structurally by living in
// its own module -- and every entry resolves to a generic, unbranded
// icon+color, never throwing for any key including a not-yet-persisted
// future one.

void main() {
  group('serviceIdentityIconFor / serviceIdentityColorFor', () {
    test('every ServiceIdentityKey resolves to a non-null icon, never throwing', () {
      for (final ServiceIdentityKey key in ServiceIdentityKey.values) {
        expect(() => serviceIdentityIconFor(key), returnsNormally, reason: key.storageValue);
      }
    });

    test('every ServiceIdentityKey resolves to a non-null color in both themes, never throwing', () {
      for (final ServiceIdentityKey key in ServiceIdentityKey.values) {
        expect(() => serviceIdentityColorFor(key, isDark: false), returnsNormally, reason: key.storageValue);
        expect(() => serviceIdentityColorFor(key, isDark: true), returnsNormally, reason: key.storageValue);
      }
    });

    test('distinct families resolve to distinct icons (not one generic icon for everything)', () {
      final Set<Object> icons = ServiceIdentityKey.values.map(serviceIdentityIconFor).toSet();
      expect(icons.length, greaterThan(1));
    });
  });

  group('ServiceIdentityKey.fromStorageValue', () {
    test('round-trips every value\'s own storageValue', () {
      for (final ServiceIdentityKey key in ServiceIdentityKey.values) {
        expect(ServiceIdentityKey.fromStorageValue(key.storageValue), key);
      }
    });

    test('null and an unrecognized string both fall back to .other, never throwing', () {
      expect(ServiceIdentityKey.fromStorageValue(null), ServiceIdentityKey.other);
      expect(ServiceIdentityKey.fromStorageValue('not_a_real_service'), ServiceIdentityKey.other);
    });
  });
}
