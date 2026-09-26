/// The lifecycle state of one physical cheque -- see
/// `lib/core/database/tables.dart`'s `Cheques` doc for the full
/// accounting model this freezes. Checkpoint N.
///
/// **Every one of [cleared]/[bounced]/[stopped]/[cancelled] is reachable
/// ONLY from [pending]** -- `ChequeRepository` enforces this, re-checked
/// inside the same database transaction that performs the transition
/// (see that repository's own doc for the idempotency guarantee this
/// gives). There is deliberately no bounce-after-clear reversal flow and
/// no clear-after-bounce recovery flow in V1 -- both are real-world but
/// rare cases that would require an explicit compensating-transaction
/// mechanism this checkpoint defers rather than build unsafely. This
/// means [cleared] and [bounced] are mutually exclusive for the life of
/// a `Cheques` row: a cheque that has posted its one `Transactions` row
/// can never, in V1, un-post it or acquire a second, contradictory
/// status.
///
/// [stopped] is only ever a valid target for `ChequeDirection.issued`
/// (a stop-payment instruction only makes sense for a cheque the user
/// themselves drew) -- `ChequeRepository.markStopped` rejects it for
/// `ChequeDirection.received`. [cancelled] is valid for either
/// direction (an issuer voiding a cheque before it ever circulated, or
/// a payee/payer agreeing to void a received cheque before deposit).
///
/// Only [pending]/[cleared]/[bounced]/[stopped]/[cancelled] exist in V1
/// -- there is no "partially cleared" or "cleared then disputed" state.
///
/// Stored as [Enum.name] on `Cheques.status` -- see that column's own
/// doc, and `ChequeDirection`'s own doc, for why this table uses plain
/// `.byName()` parsing rather than a defensive `fromStorageValue`.
enum ChequeStatus {
  /// Recorded but not yet resolved. Never posts a `Transactions` row,
  /// and is therefore invisible to every balance/available-money/
  /// net-worth calculation -- an issued pending cheque never reduces
  /// the drawing account's cleared balance, and a received pending
  /// cheque is never counted as available/liquid money.
  pending,

  /// Actually posted -- `Cheques.transactionId` names the exactly-one
  /// `Transactions` row this created (an expense for
  /// `ChequeDirection.issued`, an income for `ChequeDirection.received`).
  cleared,

  /// The bank refused the cheque. Never posts a `Transactions` row --
  /// an issued cheque that bounces never appears as a cleared
  /// withdrawal, and a received cheque that bounces is never counted
  /// as available money.
  bounced,

  /// `ChequeDirection.issued` only: the user instructed their bank not
  /// to honor this cheque while it was still outstanding. Never posts a
  /// `Transactions` row.
  stopped,

  /// Either direction: voided before any bank action -- e.g. the
  /// issuer tore it up before handing it over, or a received cheque was
  /// returned to its payer before deposit. Never posts a `Transactions`
  /// row.
  cancelled,
}
