import 'package:ai_financial_coach/core/finance/deposit_status.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint J item 8: `DepositStatus.fromMaturityDate` is a pure
// function of exactly two calendar-only UTC dates -- it must never
// accept or read an `AccountRow`, so these tests exercise it purely
// with hand-built `DateTime.utc(...)` values and never touch the
// database at all.
void main() {
  group('DepositStatus.fromMaturityDate', () {
    test('today strictly before maturity date -> active', () {
      final DepositStatus status = DepositStatus.fromMaturityDate(
        maturityDateUtc: DateTime.utc(2027, 1, 1),
        nowUtc: DateTime.utc(2026, 12, 31),
      );
      expect(status, DepositStatus.active);
    });

    test('today exactly on maturity date -> matured (term has fully elapsed)', () {
      final DepositStatus status = DepositStatus.fromMaturityDate(
        maturityDateUtc: DateTime.utc(2026, 6, 15),
        nowUtc: DateTime.utc(2026, 6, 15),
      );
      expect(status, DepositStatus.matured);
    });

    test('today strictly after maturity date -> matured', () {
      final DepositStatus status = DepositStatus.fromMaturityDate(
        maturityDateUtc: DateTime.utc(2020, 1, 1),
        nowUtc: DateTime.utc(2026, 9, 25),
      );
      expect(status, DepositStatus.matured);
    });

    test('one day before maturity -> still active (boundary just inside term)', () {
      final DepositStatus status = DepositStatus.fromMaturityDate(
        maturityDateUtc: DateTime.utc(2026, 3, 10),
        nowUtc: DateTime.utc(2026, 3, 9),
      );
      expect(status, DepositStatus.active);
    });

    test('one day after maturity -> matured (boundary just outside term)', () {
      final DepositStatus status = DepositStatus.fromMaturityDate(
        maturityDateUtc: DateTime.utc(2026, 3, 10),
        nowUtc: DateTime.utc(2026, 3, 11),
      );
      expect(status, DepositStatus.matured);
    });
  });
}
