# Testing Strategy — V2

## Unit tests

Cover:

- fixed-precision money arithmetic
- zero-decimal currencies (e.g. JPY/KRW behavior)
- three-decimal currencies (e.g. KWD behavior)
- account totals
- income/expense totals
- transfer exclusion from income/expense
- category totals
- budgets
- goal projections
- goal contribution conversion
- recurring dates
- timezone handling
- currency conversion
- historical FX snapshot immutability
- stale FX behavior
- notification rules

## Integration tests

- authentication
- transaction CRUD
- offline queue
- sync idempotency
- conflict handling
- receipt upload/process/confirm
- FX provider/cache/fallback
- recurring transaction generation
- account deletion/export
- object storage privacy

## OCR tests

Build a labeled corpus covering:

- English
- Japanese
- Korean
- mixed language
- different decimal separators
- crumpled/faded receipts
- long receipts
- shadows/perspective
- discounts/tax
- duplicate receipts
- multiple currencies

Expand with country samples from Sri Lanka, Nepal, India, Vietnam, Bangladesh, Myanmar, Qatar, Kuwait, Canada, and Ireland as the beta grows.

Metrics:

- merchant accuracy
- date accuracy
- currency accuracy
- total accuracy
- item accuracy
- duplicate detection precision/recall
- correction rate

## FX tests

Required:

- source timestamp present
- fetched timestamp present
- stale-rate UI state
- historical rate does not change after refresh
- reverse-pair conversion consistency within defined rounding tolerance
- locale formatting
- unsupported currency handling
- provider outage fallback

## Mobile tests

- first launch
- onboarding
- expense/income/transfer
- offline restart
- receipt scan
- goal contribution
- budget warning
- FX converter
- stale FX display
- recurring bill
- biometric/PIN if enabled
- dark/light mode
- accessibility basics

## AI evaluation — Later

- hallucination resistance
- deterministic number grounding
- prompt injection resistance
- category quality
- recommendation quality
- safety
- consistency

## Release gates

No release if:

- money calculations fail
- a transfer changes spending/income totals incorrectly
- transaction loss is possible
- historical FX conversion changes after a market-rate refresh
- currency precision is wrong
- stale/unknown FX data is presented as current without warning
- receipt OCR silently commits an invalid total
- account deletion fails
- privacy controls do not match implementation
- AI can fabricate balances or transactions
