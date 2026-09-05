import 'dart:convert';

/// Deterministically allocates a platform notification id (a positive
/// 32-bit-safe `int` -- `flutter_local_notifications`/Android's own
/// notification id type) for every `(ruleId, scheduledDateUtc)` pair in
/// a desired-reminder set, GUARANTEEING no two distinct pairs in the
/// same [allocate] call ever receive the same id -- Beta 1 Task 4B,
/// correction 1.
///
/// Kept entirely outside `RecurringSchedule` and the pure recurring
/// reminder planner (`recurring_reminder_planner.dart`): id allocation
/// is a notification-scheduling/platform-boundary concern, never
/// recurrence mathematics -- see `docs/14_DECISION_LOG.md` ADR-024.
///
/// **Why a hash alone is not enough:** a 32-bit hash of
/// `(ruleId, scheduledDateUtc)` can collide -- two DIFFERENT rules (or
/// the same rule on two different dates) can hash to the same id, which
/// would make one of them silently overwrite the other's OS-level
/// notification. [allocate] resolves this explicitly: it sorts every
/// key first (so the outcome never depends on the caller's iteration
/// order -- the same desired set always allocates the same ids, which
/// is what keeps repeated reconciliation passes from reassigning ids
/// out from under an already-scheduled notification), then walks the
/// sorted keys computing each one's hash-based "base id"; if that id
/// was already claimed earlier in this same pass, it deterministically
/// probes forward (`id + 1`, wrapping before the 32-bit signed max)
/// until it finds one that is not. Every key in [allocate]'s input
/// therefore ends up with a distinct id, unconditionally.
class NotificationIdAllocator {
  const NotificationIdAllocator({int Function(String ruleId, DateTime scheduledDateUtc)? baseIdFor})
      : _baseIdFor = baseIdFor ?? _defaultBaseIdFor;

  final int Function(String ruleId, DateTime scheduledDateUtc) _baseIdFor;

  /// The largest id this allocator will ever hand out -- comfortably
  /// inside a signed 32-bit `int`, which is what both Android and
  /// `flutter_local_notifications` require.
  static const int _maxId = 0x7FFFFFFF;

  /// FNV-1a, 32-bit -- a small, dependency-free, stable string hash.
  /// Masked to the positive half of a signed 32-bit range so the result
  /// is always a valid platform notification id on its own (before any
  /// collision probing).
  static int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    for (final int byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & _maxId;
  }

  static int _defaultBaseIdFor(String ruleId, DateTime scheduledDateUtc) {
    final String key = '$ruleId|${scheduledDateUtc.toIso8601String()}';
    final int hash = _fnv1a32(key);
    // 0 is reserved (some platform notification APIs treat id 0 as
    // "no id" / invalid) -- nudge it to 1, which cannot itself collide
    // with anything since every other base id is a full 31-bit hash.
    return hash == 0 ? 1 : hash;
  }

  /// Allocates a unique id for every key in [keys]. [ruleIdOf] and
  /// [scheduledDateUtcOf] extract the two fields identity is keyed on;
  /// [keys] itself can be any type (typically
  /// `DesiredReminder` from `recurring_reminder_planner.dart`) so this
  /// class never needs to import that domain type.
  ///
  /// Distinct keys (by `==`) always receive distinct ids. The SAME set
  /// of keys, regardless of the order [keys] is passed in, always
  /// allocates the exact same id to each key.
  Map<T, int> allocate<T>(
    Iterable<T> keys, {
    required String Function(T key) ruleIdOf,
    required DateTime Function(T key) scheduledDateUtcOf,
  }) {
    final List<T> sorted = keys.toList()
      ..sort((T a, T b) {
        final int ruleCompare = ruleIdOf(a).compareTo(ruleIdOf(b));
        if (ruleCompare != 0) return ruleCompare;
        return scheduledDateUtcOf(a).compareTo(scheduledDateUtcOf(b));
      });

    final Map<T, int> assigned = <T, int>{};
    final Set<int> claimed = <int>{};
    for (final T key in sorted) {
      int candidate = _baseIdFor(ruleIdOf(key), scheduledDateUtcOf(key));
      while (claimed.contains(candidate)) {
        candidate = candidate >= _maxId ? 1 : candidate + 1;
      }
      claimed.add(candidate);
      assigned[key] = candidate;
    }
    return assigned;
  }
}
