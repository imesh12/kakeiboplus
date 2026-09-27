import 'package:ai_financial_coach/features/services/domain/service_identity.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U2: `ServiceIdentityFamily` (U1's `ServiceIdentityKey`,
// renamed and extended -- see this file's own doc comment) is the
// coarse visual family every service identity, named or generic,
// resolves its icon+color through. See `service_identity_catalog_test
// .dart` for the NAMED layer built on top of it.

void main() {
  group('serviceFamilyIconFor / serviceFamilyColorFor', () {
    test('every ServiceIdentityFamily resolves to a non-null icon, never throwing', () {
      for (final ServiceIdentityFamily family in ServiceIdentityFamily.values) {
        expect(() => serviceFamilyIconFor(family), returnsNormally, reason: family.storageValue);
      }
    });

    test('every ServiceIdentityFamily resolves to a non-null color in both themes, never throwing',
        () {
      for (final ServiceIdentityFamily family in ServiceIdentityFamily.values) {
        expect(
          () => serviceFamilyColorFor(family, isDark: false),
          returnsNormally,
          reason: family.storageValue,
        );
        expect(
          () => serviceFamilyColorFor(family, isDark: true),
          returnsNormally,
          reason: family.storageValue,
        );
      }
    });

    test('distinct families resolve to distinct icons (not one generic icon for everything)', () {
      final Set<Object> icons = ServiceIdentityFamily.values.map(serviceFamilyIconFor).toSet();
      expect(icons.length, greaterThan(1));
    });
  });

  group('ServiceIdentityFamily.fromStorageValue', () {
    test('round-trips every value\'s own storageValue', () {
      for (final ServiceIdentityFamily family in ServiceIdentityFamily.values) {
        expect(ServiceIdentityFamily.fromStorageValue(family.storageValue), family);
      }
    });

    test('null and an unrecognized string both fall back to .other, never throwing', () {
      expect(ServiceIdentityFamily.fromStorageValue(null), ServiceIdentityFamily.other);
      expect(ServiceIdentityFamily.fromStorageValue('not_a_real_family'), ServiceIdentityFamily.other);
    });
  });
}
