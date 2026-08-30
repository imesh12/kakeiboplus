# Private Beta Build Plan

## Goal

Ship a stable friends-and-family build before expanding product scope.

## Beta 0 — Developer Build

Purpose: prove the local money engine.

Build:

- Flutter shell
- navigation
- Drift schema/migrations
- profile
- accounts
- categories
- expense/income/transfer
- transaction history
- deterministic balances
- offline persistence
- unit tests for money/currency precision

Exit criteria:

- no transaction loss after app restart
- transfers do not affect spending/income totals
- JPY/KRW/KWD precision tests pass

## Beta 1 — Daily Use

Add:

- dashboard
- budgets
- savings goals
- goal contributions
- milestones
- recurring bills
- basic notifications
- home/living currency display

Test with roughly 5–10 trusted users.

Measure:

- first transaction completion
- transactions per active user
- goal creation
- contribution frequency
- 7-day retention
- major confusion points

## Beta 2 — FX

Add:

- FX provider backend/client
- favorites
- converter
- source/timestamp
- stale state
- historical snapshots

Test international pairs relevant to actual testers.

Exit criteria:

- rate provenance is visible
- cached rate behavior is understandable
- historical converted transactions do not change after refresh

## Beta 3 — Receipts

Add:

- camera/import
- OCR
- merchant/date/currency/total extraction
- review/confirm
- duplicate detection

Initial corpus:

- English
- Japanese
- Korean

Measure:

- scan success
- total accuracy
- correction rate
- time saved vs manual entry

## Beta 4 — Cloud

Only after local reliability:

- authentication
- encrypted backup
- FastAPI/PostgreSQL
- sync
- multi-device
- receipt retention controls

Exit criteria:

- idempotent sync
- conflict tests
- deletion/export tests
- no duplicate financial records

## Beta 5 — Intelligence

First add deterministic insights:

- category change vs prior month
- budget risk
- upcoming bills
- goal pace
- savings rate

Only then evaluate AI coach.

## What not to build during early beta

- direct bank integration
- actual remittance
- trading
- complex family permissions
- huge gamification system
- full-language OCR promise
- dozens of AI agents

## Feedback template

Ask testers:

1. What did you try to do?
2. Could you do it without help?
3. What felt slow or confusing?
4. Did you use the FX feature instead of Google/search?
5. Did a savings goal make you contribute money more intentionally?
6. Did receipt scanning save time?
7. What would make you open the app tomorrow?

## Primary success signal

Do not optimize for installs.

Optimize for:

```text
User records money
→ returns
→ checks progress/rates
→ contributes to a goal
→ keeps using the app after 30 days
```
