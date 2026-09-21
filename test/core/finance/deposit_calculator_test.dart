import 'package:ai_financial_coach/core/finance/ambiguous_compound_period_exception.dart';
import 'package:ai_financial_coach/core/finance/deposit_calculator.dart';
import 'package:ai_financial_coach/core/finance/deposit_compounding_frequency.dart';
import 'package:ai_financial_coach/core/finance/deposit_term_unit.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DepositCalculator.calculateSimpleInterest', () {
    test('item 8: interestRateBasisPoints converts to the exact rate (550 = 5.50%)', () {
      // 100000 minor units at 5.50% over exactly 365/365 days -- a clean,
      // hand-verifiable example: 100000 * 0.055 = 5500 exactly.
      final DepositEstimate estimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 550,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2027, 1, 1), // 365 days
      );
      expect(estimate.estimatedInterest.minorUnits, 5500);
    });

    test('item 9: exact known example -- 5% over exactly one year (365 days)', () {
      // 100000 * 0.05 * (365/365) = 5000.0 exactly -- no rounding is even
      // exercised here, deliberately, as the simplest possible proof the
      // formula itself is right before item 10 exercises the boundary.
      final DepositEstimate estimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 500,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2027, 1, 1),
      );
      expect(estimate.estimatedInterest.minorUnits, 5000);
    });

    test('item 10: HALF-UP boundary -- exactly .5 rounds up', () {
      // 4 minor units * 12.5% * (365/365) = 0.5 exactly -- the exact
      // HALF-UP boundary. ROUND HALF UP (ADR-018) rounds this up to 1,
      // never down to 0 and never "round half to even".
      final DepositEstimate estimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(4, 'USD'),
        interestRateBasisPoints: 1250,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2027, 1, 1), // 365 days
      );
      expect(estimate.estimatedInterest.minorUnits, 1);
    });

    test('item 10 (contrast): just below the .5 boundary rounds down', () {
      // Same principal/rate as above but 364 days -> 182/365 ≈ 0.4986,
      // strictly less than 0.5 -- rounds down to 0. Proves the boundary
      // test above is exercising ROUND HALF UP, not always-round-up.
      final DepositEstimate estimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(4, 'USD'),
        interestRateBasisPoints: 1250,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2026, 12, 31), // 364 days
      );
      expect(estimate.estimatedInterest.minorUnits, 0);
    });

    test('item 11: Actual/365 across a leap year accrues more interest than a '
        'non-leap year over the "same" Jan 1 -> Mar 1 span', () {
      // The 365 denominator NEVER changes (docs/20 §12.8) -- only the
      // actualDays numerator differs, because it comes from real
      // calendar-day subtraction: Jan 1 -> Mar 1 spans 60 days in 2028
      // (a leap year, because it includes Feb 29) but 59 days in 2026 (not
      // a leap year).
      final DepositEstimate leapYearEstimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 500,
        startDateUtc: DateTime.utc(2028, 1, 1),
        maturityDateUtc: DateTime.utc(2028, 3, 1),
      );
      final DepositEstimate nonLeapYearEstimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 500,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2026, 3, 1),
      );
      expect(leapYearEstimate.estimatedInterest.minorUnits, 822); // 60000/73 ≈ 821.918
      expect(nonLeapYearEstimate.estimatedInterest.minorUnits, 808); // 59000/73 ≈ 808.219
      expect(
        leapYearEstimate.estimatedInterest.minorUnits,
        greaterThan(nonLeapYearEstimate.estimatedInterest.minorUnits),
      );
    });

    test(
        'actualDays is instant-based, not isUtc-flag-based -- a same-'
        'instant local-flagged pair (e.g. what drift\'s default '
        'DateTimeColumn storage hands back on read, see '
        'DepositRepository._canonicalizeStoredDate) produces an identical '
        'result to the equivalent UTC-flagged pair', () {
      // DateTime.difference() (which actualDays is built on) compares only
      // the underlying instant -- unlike DateTime.== -- so it is immune to
      // the read-side isUtc-flag quirk that motivated this checkpoint's bug
      // fix. .toLocal() below only changes the flag/displayed fields, never
      // the instant, on any host running this test.
      final DateTime startUtc = DateTime.utc(2026, 1, 1);
      final DateTime maturityUtc = DateTime.utc(2027, 1, 1); // 365 days
      final DepositEstimate utcFlaggedEstimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 500,
        startDateUtc: startUtc,
        maturityDateUtc: maturityUtc,
      );
      final DepositEstimate localFlaggedEstimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 500,
        startDateUtc: startUtc.toLocal(),
        maturityDateUtc: maturityUtc.toLocal(),
      );
      expect(
        localFlaggedEstimate.estimatedInterest.minorUnits,
        utcFlaggedEstimate.estimatedInterest.minorUnits,
      );
      expect(utcFlaggedEstimate.estimatedInterest.minorUnits, 5000);
    });

    test('item 12: estimatedMaturityValue is exactly principal + estimatedInterest', () {
      final Money principal = Money.fromMinorUnits(100000, 'USD');
      final DepositEstimate estimate = DepositCalculator.calculateSimpleInterest(
        principal: principal,
        interestRateBasisPoints: 550,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2026, 7, 1), // an irregular day count
      );
      expect(
        estimate.estimatedMaturityValue.minorUnits,
        principal.minorUnits + estimate.estimatedInterest.minorUnits,
      );
    });

    test('item 20: zero principal produces zero interest and zero maturity value', () {
      final DepositEstimate estimate = DepositCalculator.calculateSimpleInterest(
        principal: Money.fromMinorUnits(0, 'USD'),
        interestRateBasisPoints: 550,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2027, 1, 1),
      );
      expect(estimate.estimatedInterest.minorUnits, 0);
      expect(estimate.estimatedMaturityValue.minorUnits, 0);
    });

    test('item 21: zero interest rate produces zero interest; maturity value equals principal', () {
      final Money principal = Money.fromMinorUnits(100000, 'USD');
      final DepositEstimate estimate = DepositCalculator.calculateSimpleInterest(
        principal: principal,
        interestRateBasisPoints: 0,
        startDateUtc: DateTime.utc(2026, 1, 1),
        maturityDateUtc: DateTime.utc(2027, 1, 1),
      );
      expect(estimate.estimatedInterest.minorUnits, 0);
      expect(estimate.estimatedMaturityValue.minorUnits, principal.minorUnits);
    });

    test('rejects a negative principal', () {
      expect(
        () => DepositCalculator.calculateSimpleInterest(
          principal: Money.fromMinorUnits(-1, 'USD'),
          interestRateBasisPoints: 550,
          startDateUtc: DateTime.utc(2026, 1, 1),
          maturityDateUtc: DateTime.utc(2027, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative interest rate', () {
      expect(
        () => DepositCalculator.calculateSimpleInterest(
          principal: Money.fromMinorUnits(100000, 'USD'),
          interestRateBasisPoints: -1,
          startDateUtc: DateTime.utc(2026, 1, 1),
          maturityDateUtc: DateTime.utc(2027, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a maturity date before the start date', () {
      expect(
        () => DepositCalculator.calculateSimpleInterest(
          principal: Money.fromMinorUnits(100000, 'USD'),
          interestRateBasisPoints: 550,
          startDateUtc: DateTime.utc(2026, 1, 1),
          maturityDateUtc: DateTime.utc(2025, 12, 31),
        ),
        throwsArgumentError,
      );
    });
  });

  group('DepositCalculator.calculateCompoundInterest', () {
    test('item 17: valid whole-period example -- 12% annual, monthly compounding, '
        '12-month term', () {
      // periodRate = 12%/12 = 1% exactly; growth = 1.01^12 ≈ 1.126825030...;
      // 100000 * that growth ≈ 112682.5030... -> rounds HALF UP to 112683
      // (hand-verified with exact rational arithmetic, not a float).
      final DepositEstimate estimate = DepositCalculator.calculateCompoundInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 1200,
        compoundingFrequency: DepositCompoundingFrequency.monthly,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
      );
      expect(estimate.estimatedMaturityValue.minorUnits, 112683);
      expect(estimate.estimatedInterest.minorUnits, 12683);
    });

    test('item 17 (contrast): the same term/rate expressed in years gives the '
        'identical result', () {
      final DepositEstimate estimate = DepositCalculator.calculateCompoundInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 1200,
        compoundingFrequency: DepositCompoundingFrequency.monthly,
        termNumber: 1,
        termUnit: DepositTermUnit.years,
      );
      expect(estimate.estimatedMaturityValue.minorUnits, 112683);
    });

    test('item 18: compound HALF-UP -- exactly .5 rounds up', () {
      // periodRate = 20%/4 = 5% exactly; growth = 1.05^2 = 1.1025 exactly;
      // 200 * 1.1025 = 220.5 exactly -- the exact HALF-UP boundary.
      final DepositEstimate estimate = DepositCalculator.calculateCompoundInterest(
        principal: Money.fromMinorUnits(200, 'USD'),
        interestRateBasisPoints: 2000,
        compoundingFrequency: DepositCompoundingFrequency.quarterly,
        termNumber: 6,
        termUnit: DepositTermUnit.months,
      );
      expect(estimate.estimatedMaturityValue.minorUnits, 221);
      expect(estimate.estimatedInterest.minorUnits, 21);
    });

    test('atMaturity over an exact 1-year term is equivalent to simple '
        'interest over that year', () {
      // atMaturity is always 1 period, but that period's rate is scaled
      // by the term's fraction of a year (totalMonths/12) -- for a
      // 12-month term that fraction is exactly 1, so
      // maturityValue = principal * (1 + rate), identical to simple
      // interest over exactly one year (docs/20 §12.8's "equivalent to
      // simple interest for that case").
      final DepositEstimate estimate = DepositCalculator.calculateCompoundInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 550,
        compoundingFrequency: DepositCompoundingFrequency.atMaturity,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
      );
      expect(estimate.estimatedInterest.minorUnits, 5500);
    });

    test('atMaturity scales its single period\'s rate by the term\'s actual '
        'length -- a 6-month term earns half the annual rate, not the full rate', () {
      // This is the behavior that distinguishes atMaturity from "apply
      // the flat annual rate regardless of term length" (which would
      // silently overstate interest for any sub-year atMaturity term).
      final DepositEstimate estimate = DepositCalculator.calculateCompoundInterest(
        principal: Money.fromMinorUnits(100000, 'USD'),
        interestRateBasisPoints: 550,
        compoundingFrequency: DepositCompoundingFrequency.atMaturity,
        termNumber: 6,
        termUnit: DepositTermUnit.months,
      );
      expect(estimate.estimatedInterest.minorUnits, 2750); // exactly half of 5500
    });

    test('atMaturity still requires termUnit months or years -- a day-based '
        'atMaturity term is ambiguous too', () {
      // atMaturity is NOT exempt from the calendar-month requirement: its
      // single period's rate must still be scaled by an exact
      // months-fraction of a year, which a day count cannot provide
      // unambiguously.
      expect(
        () => DepositCalculator.calculateCompoundInterest(
          principal: Money.fromMinorUnits(100000, 'USD'),
          interestRateBasisPoints: 550,
          compoundingFrequency: DepositCompoundingFrequency.atMaturity,
          termNumber: 30,
          termUnit: DepositTermUnit.days,
        ),
        throwsA(isA<AmbiguousCompoundPeriodException>()),
      );
    });

    test('item 19: a day-based term with month-based compounding is ambiguous', () {
      expect(
        () => DepositCalculator.calculateCompoundInterest(
          principal: Money.fromMinorUnits(100000, 'USD'),
          interestRateBasisPoints: 1200,
          compoundingFrequency: DepositCompoundingFrequency.monthly,
          termNumber: 90,
          termUnit: DepositTermUnit.days,
        ),
        throwsA(isA<AmbiguousCompoundPeriodException>()),
      );
    });

    test('item 19: a term that is not a whole number of compounding periods is '
        'ambiguous (4 months compounded quarterly)', () {
      expect(
        () => DepositCalculator.calculateCompoundInterest(
          principal: Money.fromMinorUnits(100000, 'USD'),
          interestRateBasisPoints: 1200,
          compoundingFrequency: DepositCompoundingFrequency.quarterly,
          termNumber: 4,
          termUnit: DepositTermUnit.months,
        ),
        throwsA(isA<AmbiguousCompoundPeriodException>()),
      );
    });

    test('item 20: zero principal produces zero interest and zero maturity value', () {
      final DepositEstimate estimate = DepositCalculator.calculateCompoundInterest(
        principal: Money.fromMinorUnits(0, 'USD'),
        interestRateBasisPoints: 1200,
        compoundingFrequency: DepositCompoundingFrequency.monthly,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
      );
      expect(estimate.estimatedInterest.minorUnits, 0);
      expect(estimate.estimatedMaturityValue.minorUnits, 0);
    });

    test('item 21: zero interest rate produces zero interest; maturity value equals '
        'principal', () {
      final Money principal = Money.fromMinorUnits(100000, 'USD');
      final DepositEstimate estimate = DepositCalculator.calculateCompoundInterest(
        principal: principal,
        interestRateBasisPoints: 0,
        compoundingFrequency: DepositCompoundingFrequency.monthly,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
      );
      expect(estimate.estimatedInterest.minorUnits, 0);
      expect(estimate.estimatedMaturityValue.minorUnits, principal.minorUnits);
    });

    test('rejects a negative principal', () {
      expect(
        () => DepositCalculator.calculateCompoundInterest(
          principal: Money.fromMinorUnits(-1, 'USD'),
          interestRateBasisPoints: 1200,
          compoundingFrequency: DepositCompoundingFrequency.monthly,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative interest rate', () {
      expect(
        () => DepositCalculator.calculateCompoundInterest(
          principal: Money.fromMinorUnits(100000, 'USD'),
          interestRateBasisPoints: -1,
          compoundingFrequency: DepositCompoundingFrequency.monthly,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
        ),
        throwsArgumentError,
      );
    });
  });
}
