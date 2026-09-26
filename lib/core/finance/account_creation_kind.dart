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
/// **[savings] persists its own [FinancialAccountSubtype.savings]
/// subtype -- Checkpoint K** (resolving docs/20 §13.5's open question 1,
/// "bank is not split," in favor of splitting it). [savings] is a
/// normal, liquid asset for every accounting purpose (availability, net
/// worth, lifecycle) -- identical to [bank]/[cash]/[wallet] -- it is
/// simply persisted, identified, and reported as its own subtype rather
/// than continuing to alias [bank]'s. Before Checkpoint K, [savings] and
/// [bank] shared the exact same subtype and were distinguishable only
/// through `Accounts.type` (a presentation-only field); an account
/// created before Checkpoint K keeps whatever subtype it was created
/// with -- Checkpoint K never rewrites existing rows. [legacyTypeLabel]
/// remains `'savings'`, distinct from [bank]'s `'bank'`, unchanged by
/// this checkpoint -- it was already correct.
///
/// **[deposit] and [creditCard] are the two kinds Checkpoint G's own
/// `AccountCreationService` composes multiple records for** -- see that
/// service's own doc. Every other value here creates exactly one
/// `FinancialAccount` row and nothing else.
enum AccountCreationKind {
  cash('cash', BalanceClass.asset, FinancialAccountSubtype.cash),
  bank('bank', BalanceClass.asset, FinancialAccountSubtype.bank),
  savings('savings', BalanceClass.asset, FinancialAccountSubtype.savings),
  wallet('wallet', BalanceClass.asset, FinancialAccountSubtype.wallet),
  deposit('deposit', BalanceClass.asset, FinancialAccountSubtype.deposit),
  creditCard('creditCard', BalanceClass.liability, FinancialAccountSubtype.creditCard);

  const AccountCreationKind(this.legacyTypeLabel, this.balanceClass, this.subtype);

  /// The value stored in `Accounts.type` for an account this kind
  /// creates -- presentation-only metadata (see `Accounts.type`'s own
  /// doc in `tables.dart`), never read for any accounting decision.
  /// Distinct from every other kind's label so the existing Accounts
  /// list/detail screens can show a recognizable label/icon for each
  /// (see `account_type_presentation.dart`'s cases).
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
