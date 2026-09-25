import 'package:ai_financial_coach/core/finance/interest_rate_input.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint G follow-up verification/coverage increment, Task 5:
// `InterestRateInput` had no dedicated test file at all before this
// increment -- every case here locks in the exact contract already
// documented on the class itself (`lib/core/finance/interest_rate_input
// .dart`), rather than broadening what it accepts. This is the same
// exactness discipline `money_parser_test.dart` already applies to
// `MoneyParser` (exact `Decimal` parsing end to end, never `double`,
// reject rather than silently round/truncate excess precision).
void main() {
  group('InterestRateInput.parseAnnualRatePercentToBasisPoints', () {
    test('"0" parses to 0 basis points', () {
      expect(InterestRateInput.parseAnnualRatePercentToBasisPoints('0'), 0);
    });

    test('"0.00" (explicit zero decimals) also parses to 0 basis points', () {
      expect(InterestRateInput.parseAnnualRatePercentToBasisPoints('0.00'), 0);
    });

    test('a normal decimal percentage converts to whole basis points ("5.5" -> 550)', () {
      expect(InterestRateInput.parseAnnualRatePercentToBasisPoints('5.5'), 550);
    });

    test(
      'the maximum precision the contract accepts -- exactly 2 fractional digits -- '
      'converts exactly ("12.34" -> 1234)',
      () {
        expect(InterestRateInput.parseAnnualRatePercentToBasisPoints('12.34'), 1234);
      },
    );

    test(
      'excess precision -- a 3rd fractional digit -- is rejected outright, never silently '
      'rounded or truncated',
      () {
        expect(
          () => InterestRateInput.parseAnnualRatePercentToBasisPoints('12.345'),
          throwsA(
            isA<InterestRateInputException>().having(
              (InterestRateInputException e) => e.message,
              'message',
              'Interest rate allows at most 2 decimal digits.',
            ),
          ),
        );
      },
    );

    test('malformed (non-numeric) input is rejected with a clear message', () {
      expect(
        () => InterestRateInput.parseAnnualRatePercentToBasisPoints('abc'),
        throwsA(
          isA<InterestRateInputException>().having(
            (InterestRateInputException e) => e.message,
            'message',
            '"abc" is not a valid interest rate.',
          ),
        ),
      );
    });

    test('empty input is rejected -- "Enter an annual interest rate."', () {
      expect(
        () => InterestRateInput.parseAnnualRatePercentToBasisPoints(''),
        throwsA(
          isA<InterestRateInputException>().having(
            (InterestRateInputException e) => e.message,
            'message',
            'Enter an annual interest rate.',
          ),
        ),
      );
    });

    test('whitespace-only input trims to empty and is rejected the same way', () {
      expect(
        () => InterestRateInput.parseAnnualRatePercentToBasisPoints('   '),
        throwsA(
          isA<InterestRateInputException>().having(
            (InterestRateInputException e) => e.message,
            'message',
            'Enter an annual interest rate.',
          ),
        ),
      );
    });

    test('a negative rate is rejected -- this contract forbids it outright', () {
      expect(
        () => InterestRateInput.parseAnnualRatePercentToBasisPoints('-1'),
        throwsA(
          isA<InterestRateInputException>().having(
            (InterestRateInputException e) => e.message,
            'message',
            'Interest rate cannot be negative.',
          ),
        ),
      );
    });

    test(
      'exponent notation is rejected explicitly (mirrors MoneyParser.parse\'s identical '
      'check, since Decimal.tryParse\'s own grammar would otherwise accept it)',
      () {
        expect(
          () => InterestRateInput.parseAnnualRatePercentToBasisPoints('1e2'),
          throwsA(
            isA<InterestRateInputException>().having(
              (InterestRateInputException e) => e.message,
              'message',
              '"1e2" uses exponent notation, which is not supported for a rate.',
            ),
          ),
        );
      },
    );

    test(
      'a value whose basis-point magnitude would not fit the 31-bit overflow guard is '
      'rejected as too large, rather than wrapping',
      () {
        // 21474837 * 100 = 2,147,483,700 > 2^31 - 1 (2,147,483,647).
        expect(
          () => InterestRateInput.parseAnnualRatePercentToBasisPoints('21474837'),
          throwsA(
            isA<InterestRateInputException>().having(
              (InterestRateInputException e) => e.message,
              'message',
              'Interest rate is too large.',
            ),
          ),
        );
      },
    );

    test('leading/trailing whitespace around an otherwise-valid input is trimmed', () {
      expect(InterestRateInput.parseAnnualRatePercentToBasisPoints('  5.5  '), 550);
    });

    test(
      'decimal-separator behavior per the existing contract: only "." is a valid decimal '
      'point -- a comma-decimal locale input ("5,5") is NOT specially supported and is '
      'rejected as malformed, exactly like any other non-numeric string. This class is '
      'never broadened beyond this already-frozen contract to add locale-aware separator '
      'support in this increment.',
      () {
        expect(
          () => InterestRateInput.parseAnnualRatePercentToBasisPoints('5,5'),
          throwsA(
            isA<InterestRateInputException>().having(
              (InterestRateInputException e) => e.message,
              'message',
              '"5,5" is not a valid interest rate.',
            ),
          ),
        );
      },
    );

    test('a plain integer percentage (no decimal point at all) parses exactly', () {
      expect(InterestRateInput.parseAnnualRatePercentToBasisPoints('7'), 700);
    });
  });
}
