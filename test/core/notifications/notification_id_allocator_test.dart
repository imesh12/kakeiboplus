import 'package:ai_financial_coach/core/notifications/notification_id_allocator.dart';
import 'package:flutter_test/flutter_test.dart';

class _Key {
  const _Key(this.ruleId, this.scheduledDateUtc);
  final String ruleId;
  final DateTime scheduledDateUtc;
}

void main() {
  group('NotificationIdAllocator', () {
    test('allocates the same id to the same key across repeated calls', () {
      const NotificationIdAllocator allocator = NotificationIdAllocator();
      final List<_Key> keys = <_Key>[
        _Key('rule-a', DateTime.utc(2026, 9, 1)),
        _Key('rule-b', DateTime.utc(2026, 9, 2)),
      ];

      final Map<_Key, int> first = allocator.allocate(
        keys,
        ruleIdOf: (_Key k) => k.ruleId,
        scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
      );
      final Map<_Key, int> second = allocator.allocate(
        keys,
        ruleIdOf: (_Key k) => k.ruleId,
        scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
      );

      expect(first[keys[0]], second[keys[0]]);
      expect(first[keys[1]], second[keys[1]]);
    });

    test('allocation does not depend on the caller-supplied iteration order', () {
      const NotificationIdAllocator allocator = NotificationIdAllocator();
      final _Key a = _Key('rule-a', DateTime.utc(2026, 9, 1));
      final _Key b = _Key('rule-b', DateTime.utc(2026, 9, 2));
      final _Key c = _Key('rule-c', DateTime.utc(2026, 9, 3));

      final Map<_Key, int> forward = allocator.allocate(
        <_Key>[a, b, c],
        ruleIdOf: (_Key k) => k.ruleId,
        scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
      );
      final Map<_Key, int> reversed = allocator.allocate(
        <_Key>[c, b, a],
        ruleIdOf: (_Key k) => k.ruleId,
        scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
      );

      expect(forward[a], reversed[a]);
      expect(forward[b], reversed[b]);
      expect(forward[c], reversed[c]);
    });

    test('distinct keys always receive distinct ids, even across many entries', () {
      const NotificationIdAllocator allocator = NotificationIdAllocator();
      final List<_Key> keys = <_Key>[
        for (int ruleIndex = 0; ruleIndex < 20; ruleIndex++)
          for (int dayOffset = 0; dayOffset < 14; dayOffset++)
            _Key('rule-$ruleIndex', DateTime.utc(2026, 9, 1).add(Duration(days: dayOffset))),
      ];

      final Map<_Key, int> ids = allocator.allocate(
        keys,
        ruleIdOf: (_Key k) => k.ruleId,
        scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
      );

      expect(ids.values.toSet().length, keys.length);
    });

    test(
      'deliberately forced collisions (2+ distinct keys hashing to the same base id) are '
      'still resolved to distinct ids -- the collision-handling path',
      () {
        // Injects a base-id function that returns the SAME id for every
        // key, so every one of these keys collides at the first step --
        // proving `allocate` doesn't just trust the hash.
        const NotificationIdAllocator allocator = NotificationIdAllocator(
          baseIdFor: _alwaysSameBaseId,
        );
        final List<_Key> keys = <_Key>[
          _Key('rule-a', DateTime.utc(2026, 9, 1)),
          _Key('rule-b', DateTime.utc(2026, 9, 1)),
          _Key('rule-a', DateTime.utc(2026, 9, 2)),
        ];

        final Map<_Key, int> ids = allocator.allocate(
          keys,
          ruleIdOf: (_Key k) => k.ruleId,
          scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
        );

        expect(ids.values.toSet().length, keys.length);
        // The lowest-sorted key keeps the forced base id; later ones in
        // sort order are probed forward from it, deterministically.
        final List<_Key> sorted = keys.toList()
          ..sort((_Key x, _Key y) {
            final int r = x.ruleId.compareTo(y.ruleId);
            return r != 0 ? r : x.scheduledDateUtc.compareTo(y.scheduledDateUtc);
          });
        expect(ids[sorted[0]], 42);
        expect(ids[sorted[1]], 43);
        expect(ids[sorted[2]], 44);
      },
    );

    test('repeated allocation with forced collisions stays stable (idempotent)', () {
      const NotificationIdAllocator allocator = NotificationIdAllocator(baseIdFor: _alwaysSameBaseId);
      final List<_Key> keys = <_Key>[
        _Key('rule-a', DateTime.utc(2026, 9, 1)),
        _Key('rule-b', DateTime.utc(2026, 9, 1)),
      ];

      final Map<_Key, int> first = allocator.allocate(
        keys,
        ruleIdOf: (_Key k) => k.ruleId,
        scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
      );
      final Map<_Key, int> second = allocator.allocate(
        keys,
        ruleIdOf: (_Key k) => k.ruleId,
        scheduledDateUtcOf: (_Key k) => k.scheduledDateUtc,
      );

      expect(first[keys[0]], second[keys[0]]);
      expect(first[keys[1]], second[keys[1]]);
    });
  });
}

int _alwaysSameBaseId(String ruleId, DateTime scheduledDateUtc) => 42;
