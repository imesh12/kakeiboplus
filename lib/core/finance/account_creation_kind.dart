import 'balance_class.dart';
import 'financial_account_subtype.dart';

/// The closed set of user-facing account choices Checkpoint G's Add
/// Account flow presents -- docs/20 §13.4 checkpoint G's "what would you
/// like to add?" flow. Each value is the single source of truth mapping
/// a plain-language user choice to the frozen, already-shipped
/// [BalanceClass]/[FinancialAccountSubtype] pair that choice must create
/// (docs/20 §12.1/§12.2) -- the user is never shown either technical
/// term (per the checkpoint brief's explicit "do not expose balanceClass/
/// asset-liability enum" instruction).
///
/// **[savings] intentionally maps to the SAME [FinancialAccountSubtype.bank]
/// subtype as [bank].** Docs/20 §13.5's open question 1 freezes "bank is
/// not split" -- there is no separate `checking`/`savings` subtype, by
/// design, and this checkpoint does not introduce one (that would be a
/// database-architecture change, explicitly out of scope). "Savings
/// account" is presented as its own first-step choice purely for user
/// clarity (matching the brief's own example list); internally it
/// creates exactly the same shape a "Bank account" choice does. The two
/// remain visually distinguishable afterwards only through
/// `Accounts.type` (a presentation-only field, see `tables.dart`'s own
/// doc on that column) -- [legacyTypeLabel] is deliberately `'savings'`,
/// distinct from [bank]'s `'bank'`, so the (unmodified in this
/// checkpoint) Accounts list/detail screens still show a different
/// label/icon for the two even though their `subtype` is identical.
///
/// **[deposit] and [creditCard] are the two kinds Checkpoint G's own
/// `AccountCreationService` composes multiple records for** -- see that
/// service's own doc. Every other value here creates exactly one
/// `FinancialAccount` row and nothing else.
enum AccountCreationKind {
  cash('cash', BalanceClass.asset, FinancialAccountSubtype.cash),
  bank('bank', BalanceClass.asset, FinancialAccountSubtype.bank),
  savings('savings', BalanceClass.asset, FinancialAccountSubtype.bank),
  wallet('wallet', BalanceClass.asset, FinancialAccountSubtype.wallet),
  deposit('deposit', BalanceClass.asset, FinancialAccountSubtype.deposit),
  creditCard('creditCard', BalanceClass.liability, FinancialAccountSubtype.creditCard);

  const AccountCreationKind(this.legacyTypeLabel, this.balanceClass, this.subtype);

  /// The value stored in `Accounts.type` for an account this kind
  /// creates -- presentation-only metadata (see `Accounts.type`'s own
  /// doc in `tables.dart`), never read for any accounting decision.
  /// Distinct from every other kind's label (including [bank]/[savings],
  /// which otherwise share a [subtype]) so the existing Accounts list/
  /// detail screens -- unmodified by this checkpoint -- can still show a
  /// recognizable label/icon for each (see
  /// `account_type_presentation.dart`'s new cases).
  final String legacyTypeLabel;

  /// The frozen, authoritative asset/liability classification this kind
  /// creates -- see [BalanceClass]'s own doc.
  final BalanceClass balanceClass;

  /// The frozen, authoritative product subtype this kind creates -- see
  /// [FinancialAccountSubtype]'s own doc.
  final FinancialAccountSubtype subtype;

  /// Whether this kind's creation flow offers an optional institution
  /// selection -- every kind except [cash] (docs/20 §13.4 checkpoint G's
  /// explicit "the UX should not force an institution for cash," read as
  /// "cash has no institution to offer" -- a physical cash holding is
  /// definitionally institution-less).
  bool get allowsInstitution => this != AccountCreationKind.cash;

  /// Whether this kind's creation additionally requires a
  /// `CreditFacilityDetails` row (and a `creditCard` `PaymentInstrument`)
  /// -- see `AccountCreationService.createCreditCardAccount`.
  bool get requiresCreditFacility => this == AccountCreationKind.creditCard;

  /// Whether this kind's creation additionally requires a `DepositDetails`
  /// row -- see `AccountCreationService.createDepositAccount`.
  bool get requiresDepositDetails => this == AccountCreationKind.deposit;
}
