/// The card network of a `PaymentInstrument`, when known -- purely
/// descriptive metadata (e.g. for showing a recognizable card logo/name
/// in a future UI), never used in any accounting calculation.
///
/// Deliberately NOT a `FinancialInstitution` -- a network (Visa,
/// Mastercard, ...) is not "who the money is with" the way a bank or
/// wallet provider is; see `FinancialInstitutions`' own doc in
/// `tables.dart`. [network] is always optional and is null for
/// instruments that genuinely have none (a cash card, most payment
/// services) or where the user doesn't know/care -- V1 never requires
/// it.
///
/// Small, explicit V1 taxonomy plus [other] for a network that doesn't
/// fit the four listed (e.g. UnionPay, Discover, a domestic-only
/// network) -- the same "do not guess, use a named reviewable fallback"
/// discipline `PaymentInstrumentType.other`/
/// `FinancialAccountSubtype.legacyUnknownNeedsReview` already establish.
///
/// Stored as [storageValue] in a plain nullable `TextColumn` -- the same
/// enum-as-text convention `BalanceClass`/`FinancialAccountSubtype`
/// already established. [fromStorageValue] never throws on an
/// unrecognized/corrupt value -- falling back to [other].
enum CardNetwork {
  visa('visa'),
  mastercard('mastercard'),
  jcb('jcb'),
  amex('amex'),
  other('other');

  const CardNetwork(this.storageValue);

  final String storageValue;

  static CardNetwork fromStorageValue(String value) {
    return CardNetwork.values.firstWhere(
      (CardNetwork network) => network.storageValue == value,
      orElse: () => CardNetwork.other,
    );
  }
}
