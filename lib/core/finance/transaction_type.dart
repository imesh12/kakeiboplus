/// Mirrors the `type` enum on the `transactions` table in
/// `docs/03_DATABASE_SCHEMA.md`.
///
/// Beta 0 only ever constructs [expense], [income], and [transfer] —
/// [refund] and [adjustment] exist in the type so the schema and this
/// enum don't need to change shape when a later stage defines their
/// financial semantics, but nothing in Beta 0 creates them yet. See
/// `FinanceEngine` for what happens if one is encountered anyway.
enum TransactionType {
  expense,
  income,
  transfer,
  refund,
  adjustment,
}
