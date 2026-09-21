/// The product shape of a deposit -- `DepositDetails.depositType`, frozen
/// by `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §12.1's exact
/// field list. Purely descriptive metadata: it never itself drives
/// interest arithmetic (`DepositCalculator` only ever reads
/// `interestMethod`/`compoundingFrequency`/`termNumber`/`termUnit`), but
/// [recurring] does gate which fields `DepositRepository.createDetails`
/// permits -- `installmentAmountMinorUnits`/`installmentFrequency` are
/// rejected for any other value (docs/20 §12.9).
///
/// Unlike [FinancialAccountSubtype]/[PaymentInstrumentType]
/// (`fromStorageValue` never throws, falling back to a safe "needs
/// review" value), [fromStorageValue] here THROWS on an unrecognized
/// stored value instead. Those two enums had to tolerate real
/// *pre-existing* production data written before the enum existed
/// (legacy `accounts.type` strings); `deposit_details` is a brand-new
/// Checkpoint F table with zero pre-existing rows -- every row this app
/// will ever read back was itself written by
/// `DepositRepository.createDetails`, which already validates
/// [depositType] before insert. A corrupt/unrecognized value here
/// indicates a genuine bug, not legacy drift, and \[recurring\]'s
/// installment-field gating means silently falling back to some other
/// value could silently misinterpret which validation rule applied at
/// write time -- so this throws rather than guesses, per this
/// checkpoint's own "do not silently infer missing bank rules" /
/// "do not guess bank behavior" instructions.
enum DepositType {
  fixed('fixed'),
  shortTerm('shortTerm'),
  recurring('recurring'),
  other('other');

  const DepositType(this.storageValue);

  final String storageValue;

  static DepositType fromStorageValue(String value) {
    return DepositType.values.firstWhere(
      (DepositType type) => type.storageValue == value,
      orElse: () => throw FormatException('Unrecognized DepositType storage value: $value'),
    );
  }
}
