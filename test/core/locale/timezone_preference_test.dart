import 'package:ai_financial_coach/core/locale/timezone_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimezoneRegistry', () {
    const List<String> requiredIds = <String>[
      'UTC',
      'Asia/Tokyo',
      'Asia/Seoul',
      'Asia/Ho_Chi_Minh',
      'Asia/Kuwait',
      'Asia/Colombo',
      'Asia/Kathmandu',
      'Asia/Kolkata',
      'Asia/Dhaka',
      'Asia/Yangon',
      'Asia/Qatar',
      'America/Toronto',
      'Europe/Dublin',
      'America/New_York',
    ];

    test('every required IANA id is present in supported', () {
      final Set<String> supportedIds =
          TimezoneRegistry.supported.map((TimezonePreference p) => p.id).toSet();
      for (final String id in requiredIds) {
        expect(supportedIds, contains(id));
      }
    });

    test('supported is exactly the required id set -- no extras, no omissions', () {
      expect(
        TimezoneRegistry.supported.map((TimezonePreference p) => p.id).toSet(),
        requiredIds.toSet(),
      );
    });

    test('supported ids are unique', () {
      final List<String> ids =
          TimezoneRegistry.supported.map((TimezonePreference p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('byId resolves each known id to its exact preference', () {
      expect(TimezoneRegistry.byId('UTC'), TimezoneRegistry.utc);
      expect(TimezoneRegistry.byId('Asia/Tokyo'), TimezoneRegistry.tokyo);
      expect(TimezoneRegistry.byId('Asia/Seoul'), TimezoneRegistry.seoul);
      expect(TimezoneRegistry.byId('Asia/Ho_Chi_Minh'), TimezoneRegistry.hoChiMinhCity);
      expect(TimezoneRegistry.byId('Asia/Kuwait'), TimezoneRegistry.kuwaitCity);
      expect(TimezoneRegistry.byId('Asia/Colombo'), TimezoneRegistry.colombo);
      expect(TimezoneRegistry.byId('Asia/Kathmandu'), TimezoneRegistry.kathmandu);
      expect(TimezoneRegistry.byId('Asia/Kolkata'), TimezoneRegistry.kolkata);
      expect(TimezoneRegistry.byId('Asia/Dhaka'), TimezoneRegistry.dhaka);
      expect(TimezoneRegistry.byId('Asia/Yangon'), TimezoneRegistry.yangon);
      expect(TimezoneRegistry.byId('Asia/Qatar'), TimezoneRegistry.qatar);
      expect(TimezoneRegistry.byId('America/Toronto'), TimezoneRegistry.toronto);
      expect(TimezoneRegistry.byId('Europe/Dublin'), TimezoneRegistry.dublin);
      expect(TimezoneRegistry.byId('America/New_York'), TimezoneRegistry.newYork);
    });

    test('byId is case-sensitive -- a differently-cased known id does not match and falls back', () {
      expect(TimezoneRegistry.byId('asia/tokyo'), TimezoneRegistry.fallback);
      expect(TimezoneRegistry.byId('utc'), TimezoneRegistry.fallback);
      expect(TimezoneRegistry.byId('ASIA/TOKYO'), TimezoneRegistry.fallback);
    });

    test('byId falls back to UTC for null', () {
      expect(TimezoneRegistry.byId(null), TimezoneRegistry.utc);
    });

    test('byId falls back to UTC for an unknown or corrupt id', () {
      expect(TimezoneRegistry.byId('Mars/Olympus_Mons'), TimezoneRegistry.utc);
      expect(TimezoneRegistry.byId(''), TimezoneRegistry.utc);
      expect(TimezoneRegistry.byId('garbage'), TimezoneRegistry.utc);
    });

    test('fallback is UTC', () {
      expect(TimezoneRegistry.fallback, TimezoneRegistry.utc);
    });

    test('every supported entry has a non-empty English display name', () {
      for (final TimezonePreference preference in TimezoneRegistry.supported) {
        expect(preference.englishName, isNotEmpty);
      }
    });
  });
}
