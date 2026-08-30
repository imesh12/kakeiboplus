# AI Financial Coach — Blueprint V2

> Track money. Save intentionally. Understand finances anywhere.

AI Financial Coach is an international-first personal money companion for Android and iOS.

It combines:

- income and expense tracking
- accounts and transfers
- budgets
- savings goals and motivation
- receipt OCR
- recurring money
- multi-currency and FX reference rates
- analytics
- optional cloud sync
- AI coaching later

## Core philosophy

Financial truth is deterministic.

```text
Local/Server Financial Data
↓
Deterministic Money Engine
↓
Budget / Goal / FX / Analytics Rules
↓
AI Interpretation (later)
```

An LLM must never become the authoritative source for balances, totals, goal progress, or exchange-rate arithmetic.

## International-first

The core profile distinguishes:

```text
Home Country
Current Country
Home Currency
Living Currency
Preferred Language
Timezone / Locale
```

Historical transactions preserve original currency and any conversion snapshot used at that time.

## Technology direction

Mobile:

- Flutter
- Dart
- Riverpod
- GoRouter
- Drift/SQLite

Backend when cloud features are enabled:

- FastAPI
- PostgreSQL
- object storage
- optional Redis/workers as workload requires

## First milestone

The first friends-and-family beta should prove:

1. users can record money quickly;
2. users understand the dashboard;
3. savings goals motivate contributions;
4. FX tools remove the need for routine external currency searches;
5. receipt scanning meaningfully reduces typing;
6. core flows remain reliable offline.

Conversational AI is intentionally deferred until the financial foundation is proven.

## Documentation

Start with:

1. `00_MASTER_BLUEPRINT.md`
2. `01_MVP_SCOPE.md`
3. `03_DATABASE_SCHEMA.md`
4. `10_ROADMAP.md`
5. `14_DECISION_LOG.md`
6. `19_PRIVATE_BETA_BUILD_PLAN.md`

## Development philosophy

```text
Implement
→ Test
→ Review
→ Document
→ Verify with real users
```
