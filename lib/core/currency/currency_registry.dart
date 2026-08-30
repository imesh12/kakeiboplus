import 'currency.dart';

/// The Beta 0 currency seed set and lookup table.
///
/// Seeded per `docs/14_DECISION_LOG.md` (Stage 1 decisions, 2026-08-30):
/// every currency named across the Blueprint V2 personas/testing lists,
/// plus VND — a zero-minor-unit currency (same family as JPY/KRW) that the
/// docs' own precision examples don't call out even though Vietnam is in
/// the OCR test-country list (see `STAGE1_BETA0_IMPLEMENTATION_PLAN.md`
/// §12/§16, finding 7).
///
/// This registry seeds the `currencies` table on first database creation
/// (see `lib/core/database/app_database.dart`); the database, not this
/// static list, is the runtime source of truth once the app has run once.
/// This list is what makes that first seed deterministic and testable
/// without a database.
class CurrencyRegistry {
  CurrencyRegistry._();

  static const List<Currency> seed = <Currency>[
    Currency(code: 'JPY', displayName: 'Japanese Yen', symbol: '¥', minorUnits: 0),
    Currency(code: 'KRW', displayName: 'South Korean Won', symbol: '₩', minorUnits: 0),
    Currency(code: 'VND', displayName: 'Vietnamese Dong', symbol: '₫', minorUnits: 0),
    Currency(code: 'KWD', displayName: 'Kuwaiti Dinar', symbol: 'د.ك', minorUnits: 3),
    Currency(code: 'LKR', displayName: 'Sri Lankan Rupee', symbol: 'Rs', minorUnits: 2),
    Currency(code: 'NPR', displayName: 'Nepalese Rupee', symbol: 'Rs', minorUnits: 2),
    Currency(code: 'INR', displayName: 'Indian Rupee', symbol: '₹', minorUnits: 2),
    Currency(code: 'BDT', displayName: 'Bangladeshi Taka', symbol: '৳', minorUnits: 2),
    Currency(code: 'MMK', displayName: 'Myanmar Kyat', symbol: 'K', minorUnits: 2),
    Currency(code: 'QAR', displayName: 'Qatari Riyal', symbol: 'ر.ق', minorUnits: 2),
    Currency(code: 'CAD', displayName: 'Canadian Dollar', symbol: r'$', minorUnits: 2),
    Currency(code: 'EUR', displayName: 'Euro', symbol: '€', minorUnits: 2),
    Currency(code: 'USD', displayName: 'US Dollar', symbol: r'$', minorUnits: 2),
  ];

  static final Map<String, Currency> _byCode = <String, Currency>{
    for (final Currency c in seed) c.code: c,
  };

  /// Returns the [Currency] for [code], or `null` if it isn't in the
  /// Beta 0 seed set. [code] is matched case-insensitively.
  static Currency? byCode(String code) => _byCode[code.toUpperCase()];

  /// Like [byCode], but throws [ArgumentError] instead of returning null.
  /// Prefer this at call sites where an unknown currency indicates a bug
  /// (e.g. reading a currency_code back out of the database) rather than
  /// a recoverable user-facing condition.
  static Currency require(String code) {
    final Currency? currency = byCode(code);
    if (currency == null) {
      throw ArgumentError.value(code, 'code', 'Unknown currency code');
    }
    return currency;
  }
}
