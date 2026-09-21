/// The product shape of a `PaymentInstrument` -- see
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` and Checkpoint D's
/// own brief. A `PaymentInstrument` is metadata describing HOW a
/// `FinancialAccount` (physically the `accounts` table) was used to pay
/// or receive money -- it is never itself balance-holding, and this type
/// is never itself an accounting classification. In particular, a
/// [creditCard] instrument does NOT by itself mean its linked account is
/// a liability -- `PaymentInstrumentRepository`'s own creation
/// validation is what enforces the account's actual `BalanceClass`
/// matches what each instrument type requires (see that repository's
/// doc).
///
/// Checkpoint D's V1 taxonomy is deliberately small -- these are the
/// only instrument shapes with a concrete V1 use:
///
/// - [debitCard] / [cashCard]: everyday spending instruments linked to
///   an asset account (a card that draws down money already owned).
/// - [creditCard]: a spending instrument linked to a liability account
///   (money owed, not owned) -- see `docs/14_DECISION_LOG.md` ADR-035
///   and the asset/liability effect table Checkpoint C implemented.
/// - [paymentService]: a wallet-style payment provider (e.g. a mobile
///   payment app) whose underlying funding model varies by product --
///   it may draw from either an asset or a liability account, so V1
///   does not restrict its linked account's class.
/// - [other]: a deliberate, forward-compatible escape hatch for a
///   payment instrument the user has that doesn't fit the four concrete
///   V1 shapes above (e.g. a prepaid/gift card) -- exactly the same
///   "do not guess, use a named reviewable fallback" discipline
///   Checkpoint B's `FinancialAccountSubtype.legacyUnknownNeedsReview`
///   already established, rather than forcing an inaccurate
///   classification into one of the other four or blocking creation
///   entirely. [other] is treated as permissively as [paymentService]
///   for account-class validation, for the same reason: its true
///   funding model is unknown, so V1 does not assume it.
///
/// Stored as [storageValue] in a plain `TextColumn` -- the same
/// enum-as-text convention `BalanceClass`/`FinancialAccountSubtype`
/// already established in Checkpoint B. [fromStorageValue] never throws
/// on an unrecognized/corrupt value -- falling back to [other], the
/// same "unknown, needs review, never guessed" role [other] already
/// plays by design.
enum PaymentInstrumentType {
  debitCard('debitCard'),
  creditCard('creditCard'),
  cashCard('cashCard'),
  paymentService('paymentService'),
  other('other');

  const PaymentInstrumentType(this.storageValue);

  final String storageValue;

  static PaymentInstrumentType fromStorageValue(String value) {
    return PaymentInstrumentType.values.firstWhere(
      (PaymentInstrumentType type) => type.storageValue == value,
      orElse: () => PaymentInstrumentType.other,
    );
  }
}
