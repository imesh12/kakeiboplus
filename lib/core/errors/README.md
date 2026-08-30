# errors — colocated, not centralized, in Beta 0

Beta 0 does not use a centralized `Result`/`Failure` wrapper type. Error
handling is done with specific, typed exceptions colocated with the
domain they belong to, and callers use ordinary `try`/`catch`:

- `lib/core/money/currency_mismatch_exception.dart` —
  `CurrencyMismatchException`, thrown by `Money` arithmetic and by
  `TransactionRepository.recordTransfer` for a cross-currency transfer
  attempt (ADR-019).
- `lib/core/money/money_parse_exception.dart` — `MoneyParseException`,
  thrown by `MoneyParser` for invalid/imprecise user input, with a
  message written to be shown directly in a form.

This directory exists (per the approved Stage 1 `lib/` layout) as the
place a shared `Result`/`Failure` type would live if one becomes valuable
later — e.g. if a future feature needs to distinguish "not found" from
"validation failed" from "unexpected" more uniformly than typed
exceptions do on their own. Nothing currently requires that, so nothing
speculative was added here.
