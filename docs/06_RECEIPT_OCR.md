# Receipt OCR Specification — V2

## Goal

Convert a receipt image into a **reviewable structured transaction** with minimal manual correction, without silently trusting uncertain OCR.

## Pipeline

```text
Camera / Gallery
↓
Image validation
↓
Document detection
↓
Perspective / rotation correction
↓
Crop / enhancement
↓
OCR
↓
Layout parsing
↓
Merchant normalization
↓
Date / currency / total extraction
↓
Item extraction
↓
Subtotal / tax / total validation
↓
Duplicate detection
↓
Category suggestion
↓
Confidence scoring
↓
User review
↓
Confirmed transaction save
```

## Required extracted fields

Prioritize:

- merchant
- date
- currency
- total

Then:

- subtotal
- tax
- discount
- payment method where reliable
- receipt number
- individual items

## Confidence

Maintain confidence at field level where practical.

Examples:

- merchant confidence
- date confidence
- total confidence
- currency confidence
- item confidence

Low confidence must be visible to the user.

## Validation

- line totals vs subtotal
- subtotal ± tax/discount vs total
- plausible date
- plausible currency for receipt/context
- duplicate merchant/date/amount checks
- impossible or ambiguous numeric formats
- decimal separator handling by locale

## International rollout

Architecture must support multilingual OCR from day one, but coverage should expand progressively.

### Private beta priority

1. English
2. Japanese
3. Korean

### Expansion test corpus

Add real receipt samples, with permission and redaction where needed, from:

- Sri Lanka
- Nepal
- India
- Vietnam
- Bangladesh
- Myanmar
- Qatar
- Kuwait
- Canada
- Ireland

Language support should be driven by measured OCR success, not marketing claims.

## Currency handling

The scanner must identify the receipt's **original currency**. If the app displays a home-currency equivalent, that conversion is separate metadata and must not overwrite the original receipt amount.

## Duplicate detection

Use a combination of:

- merchant
- date/time
- total
- currency
- account
- receipt fingerprint/image hash where privacy design permits

## Privacy

- compress before upload where appropriate
- allow local-only processing/retention modes where feasible
- use short-lived secure upload URLs
- define receipt retention settings
- permit image deletion while retaining the confirmed transaction
- do not use receipt images for unrelated AI training without explicit permission
