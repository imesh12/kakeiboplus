/// Which way one physical cheque moves money, relative to the app's
/// user -- see `lib/core/database/tables.dart`'s `Cheques` doc for the
/// full accounting model. Checkpoint N.
///
/// Stored as [Enum.name] on `Cheques.direction` (plain text, parsed via
/// `.byName()`) -- see that column's own doc for why this table uses
/// that convention rather than `BalanceClass`/`FinancialAccountSubtype`'s
/// defensive `storageValue`/`fromStorageValue` pattern: `ChequeRepository`
/// is the only writer of this column and there is no legacy-migration
/// data to tolerate.
enum ChequeDirection {
  /// Written by the user, drawn on one of their own `ChequeBooks` --
  /// clearing posts an expense.
  issued,

  /// Written by someone else, payable to the user, deposited into one
  /// of their own eligible accounts -- clearing posts an income.
  received,
}
