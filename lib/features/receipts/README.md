# receipts — reserved for Beta 3

Not implemented yet — no OCR, no camera capture, no receipt review flow.
See Decision 13 (`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §16) and
`docs/19_PRIVATE_BETA_BUILD_PLAN.md` Beta 3.

The `receipts` and `receipt_items` tables from `docs/03_DATABASE_SCHEMA.md`
are not part of the Beta 0 schema, and `transactions.receipt_id` does not
exist in Beta 0 either (Decision 8 — no speculative foreign keys to
tables that don't exist yet). When this feature is built, follow
`docs/06_RECEIPT_OCR.md` and `CLAUDE_PROJECT_INSTRUCTIONS.md`'s
receipt/OCR rules: OCR is an assistant, never authoritative financial
data — a low-confidence extraction always requires explicit user
confirmation before it becomes a transaction.
