# Blueprint V2 Changelog

## Why V2 exists

The original blueprint was strong technically but prioritized the AI coach before fully reflecting the needs of an international friends-and-family tester group.

V2 changes the product emphasis from:

```text
Finance Tracker + AI Coach
```

to:

```text
Global Money Companion
= Track + Save + Understand + Multi-Currency
+ Receipt Intelligence
+ AI Later
```

## Major changes

1. Multi-currency moved from advanced/P1 to core/P0 architecture.
2. Added home country/current country.
3. Added home currency/living currency.
4. Added explicit FX subsystem and API.
5. Added provider/timestamp/stale-rate rules.
6. Added historical FX snapshot invariants.
7. Added currency minor-unit/precision requirements.
8. Elevated savings motivation and goal contributions.
9. Added recurring transaction model.
10. Added localization-ready architecture from day one.
11. Added international receipt/OCR rollout strategy.
12. Reduced first private beta to approximately 15–25 meaningful screens.
13. Removed conversational AI from private-beta requirements.
14. Kept Flutter + FastAPI + PostgreSQL architecture.
15. Kept deterministic-first financial calculations.
16. Kept offline-first design.
17. Added sync/data model concepts needed before cloud rollout.

## Documents updated

- 00_MASTER_BLUEPRINT.md
- 01_MVP_SCOPE.md
- 02_SCREEN_CATALOG.md
- 03_DATABASE_SCHEMA.md
- 04_API_SPECIFICATION.md
- 06_RECEIPT_OCR.md
- 09_TESTING_STRATEGY.md
- 10_ROADMAP.md
- 14_DECISION_LOG.md
- 16_PRODUCT_BACKLOG.md
- 17_README.md
- DOCUMENTATION_INDEX.md

## New documents

- 18_BLUEPRINT_V2_CHANGELOG.md
- 19_PRIVATE_BETA_BUILD_PLAN.md

## Documents intentionally preserved

AI architecture, security/privacy, notifications, DevOps, definition of done, release checklist, and Codex development rules remain valuable. Their behavior is subordinate to V2 decisions where a conflict exists.
