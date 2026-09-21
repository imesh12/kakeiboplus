import 'package:ai_financial_coach/core/finance/card_network.dart';
import 'package:ai_financial_coach/core/finance/payment_instrument_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentInstrumentType.fromStorageValue', () {
    for (final PaymentInstrumentType type in PaymentInstrumentType.values) {
      test('${type.name} round-trips through its own storageValue', () {
        expect(PaymentInstrumentType.fromStorageValue(type.storageValue), type);
      });
    }

    test('an unrecognized/corrupt value falls back to other, never throws', () {
      expect(PaymentInstrumentType.fromStorageValue('somethingCorrupt'), PaymentInstrumentType.other);
      expect(PaymentInstrumentType.fromStorageValue(''), PaymentInstrumentType.other);
    });
  });

  group('CardNetwork.fromStorageValue', () {
    for (final CardNetwork network in CardNetwork.values) {
      test('${network.name} round-trips through its own storageValue', () {
        expect(CardNetwork.fromStorageValue(network.storageValue), network);
      });
    }

    test('an unrecognized/corrupt value falls back to other, never throws', () {
      expect(CardNetwork.fromStorageValue('somethingCorrupt'), CardNetwork.other);
      expect(CardNetwork.fromStorageValue(''), CardNetwork.other);
    });
  });
}
