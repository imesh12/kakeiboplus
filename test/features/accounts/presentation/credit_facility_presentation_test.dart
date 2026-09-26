import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/accounts/presentation/credit_facility_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint O: pure unit tests for the presentation-only derivations
// `CreditFacilityPresentation` computes -- available credit and
// utilization. No database/Flutter widget tree involved; every case
// from this checkpoint's own brief (normal/zero/at-limit/over-limit/
// missing-limit) is exercised directly against the class's public
// getters.
void main() {
  group('CreditFacilityPresentation.hasConfiguredLimit', () {
    test('true for a positive limit', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.zero('JPY'),
      );
      expect(p.hasConfiguredLimit, isTrue);
    });

    test('O. false for a zero limit -- "not yet assigned," never treated as a real 0% case', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.zero('JPY'),
        amountOwed: Money.zero('JPY'),
      );
      expect(p.hasConfiguredLimit, isFalse);
    });
  });

  group('CreditFacilityPresentation.availableCredit', () {
    test('I. normal case: limit 500,000 / owed 80,000 -> available 420,000', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.fromMinorUnits(80000, 'JPY'),
      );
      expect(p.availableCredit, Money.fromMinorUnits(420000, 'JPY'));
    });

    test('J. zero balance: owed 0 -> available equals the whole limit', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.zero('JPY'),
      );
      expect(p.availableCredit, Money.fromMinorUnits(500000, 'JPY'));
    });

    test('K. at limit: owed equals limit -> available exactly zero', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.fromMinorUnits(500000, 'JPY'),
      );
      expect(p.availableCredit, Money.zero('JPY'));
    });

    test('L. over limit: owed 550,000 / limit 500,000 -> available clamped to zero, not negative',
        () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.fromMinorUnits(550000, 'JPY'),
      );
      expect(p.availableCredit, Money.zero('JPY'));
      expect(p.availableCredit.isNegative, isFalse);
    });
  });

  group('CreditFacilityPresentation.utilizationPercent', () {
    test('M. normal case: 80,000 / 500,000 -> 16%', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.fromMinorUnits(80000, 'JPY'),
      );
      expect(p.utilizationPercent, closeTo(16.0, 0.0001));
    });

    test('J. zero balance -> 0%', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.zero('JPY'),
      );
      expect(p.utilizationPercent, closeTo(0.0, 0.0001));
    });

    test('K. at limit -> 100%', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.fromMinorUnits(500000, 'JPY'),
      );
      expect(p.utilizationPercent, closeTo(100.0, 0.0001));
    });

    test('N. over 100%: owed 550,000 / limit 500,000 -> 110%, never clamped or hidden', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(500000, 'JPY'),
        amountOwed: Money.fromMinorUnits(550000, 'JPY'),
      );
      expect(p.utilizationPercent, closeTo(110.0, 0.0001));
    });

    test('a non-round percentage is not truncated -- e.g. 16.5%', () {
      final CreditFacilityPresentation p = CreditFacilityPresentation(
        creditLimit: Money.fromMinorUnits(1000000, 'USD'),
        amountOwed: Money.fromMinorUnits(165000, 'USD'),
      );
      expect(p.utilizationPercent, closeTo(16.5, 0.0001));
    });
  });
}
