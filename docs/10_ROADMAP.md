# Product Roadmap — V2

## Stage 0 — Blueprint V2 / Architecture Freeze

- international-first product definition
- multi-currency rules
- currency precision rules
- local-first architecture
- schema/API freeze
- private-beta scope
- security/privacy baseline

## Stage 1 — Core Engine

- Flutter project
- Riverpod
- GoRouter
- Drift/SQLite
- profile
- accounts
- categories
- income
- expenses
- transfers
- deterministic finance engine
- multi-currency transaction model
- currency metadata

## Stage 2 — Daily Money UI

- onboarding
- dashboard
- activity/history
- budgets
- goals
- goal contributions
- milestones
- basic analytics
- home/living currency display

## Stage 3 — FX

- provider integration
- rate cache
- favorites
- converter
- provider/timestamps
- stale state
- historical snapshots
- basic history

## Stage 4 — Receipt Intelligence

- camera/import
- image preprocessing
- OCR
- extraction
- confirmation
- duplicate detection
- English/Japanese/Korean beta corpus

## Stage 5 — Recurring + Motivation

- recurring bills/income
- upcoming commitments
- reminders
- savings streaks
- milestones
- lightweight challenges
- weekly/monthly summaries

## Stage 6 — Cloud

- authentication
- FastAPI
- PostgreSQL
- object storage
- backup
- sync
- conflict resolution
- multi-device

## Stage 7 — AI

- AI gateway
- deterministic grounding
- coach
- spending explanations
- categorization fallback
- goal explanations
- recommendations
- reports

## Stage 8 — Advanced

- tags/groups/projects
- family sharing
- advanced localization
- advanced rate alerts
- CSV import/export
- voice
- web dashboard

## Stage 9 — Integrations / Scale

- bank integrations where supported
- remittance comparison partnerships where appropriate
- wearables
- regional integrations
- production-scale workers/cache as load requires

## Development rule

For each stage:

```text
Implement
→ Unit test
→ Integration/UI test
→ Review financial rules
→ Review privacy/security
→ Document
→ Beta verify
```
