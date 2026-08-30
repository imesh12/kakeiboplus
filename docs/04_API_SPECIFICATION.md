# API Specification — V2

Base path:

```text
/api/v1
```

The private beta may run local-first without every endpoint being live. These endpoints define the cloud contract for later sync.

## Authentication

```text
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
POST /auth/password/reset
```

## Users / Profile

```text
GET    /users/me
PATCH  /users/me
DELETE /users/me
GET    /profile
PATCH  /profile
```

## Accounts

```text
GET    /accounts
POST   /accounts
PATCH  /accounts/{id}
DELETE /accounts/{id}
```

## Transactions

```text
GET    /transactions
POST   /transactions
GET    /transactions/{id}
PATCH  /transactions/{id}
DELETE /transactions/{id}
```

Transaction responses preserve original amount/currency and may include an immutable historical conversion snapshot.

## Categories

```text
GET    /categories
POST   /categories
PATCH  /categories/{id}
DELETE /categories/{id}
```

## Receipts

```text
POST   /receipts
POST   /receipts/{id}/process
GET    /receipts/{id}
PATCH  /receipts/{id}/confirm
DELETE /receipts/{id}
```

OCR processing returns confidence and validation results; it must not silently commit uncertain financial totals.

## Goals

```text
GET    /goals
POST   /goals
GET    /goals/{id}
PATCH  /goals/{id}
DELETE /goals/{id}
POST   /goals/{id}/contributions
GET    /goals/{id}/contributions
```

## Budgets

```text
GET    /budgets
POST   /budgets
GET    /budgets/{id}
PATCH  /budgets/{id}
DELETE /budgets/{id}
```

## Recurring Money

```text
GET    /recurring
POST   /recurring
PATCH  /recurring/{id}
DELETE /recurring/{id}
GET    /recurring/upcoming
```

## FX

```text
GET    /fx/latest?base=JPY&quote=LKR
GET    /fx/convert?base=JPY&quote=LKR&amount=10000
GET    /fx/history?base=JPY&quote=LKR&from=...&to=...
GET    /fx/favorites
POST   /fx/favorites
DELETE /fx/favorites/{id}
POST   /fx/alerts
DELETE /fx/alerts/{id}
```

FX payloads should include:

```text
base_currency
quote_currency
rate
provider
provider_timestamp
fetched_at
stale
```

Rates are reference information, not guaranteed execution quotes.

## Analytics

```text
GET /analytics/summary
GET /analytics/spending
GET /analytics/cash-flow
GET /analytics/savings
GET /analytics/categories
```

## Sync

```text
POST /sync/push
GET  /sync/pull?cursor=...
GET  /sync/status
```

Sync must be idempotent and preserve deleted/versioned entities.

## Notifications

```text
GET   /notifications
PATCH /notifications/{id}/read
GET   /notification-preferences
PATCH /notification-preferences
```

## AI — Later

```text
POST /ai/chat
POST /ai/categorize
POST /ai/analyze
GET  /ai/insights
```

AI must never be used as the arithmetic source of truth.

## API requirements

- versioned APIs
- TLS
- authentication where required
- rate limiting
- idempotency for financial writes/sync
- validation
- structured error payloads
- no sensitive data in logs
- explicit timestamps/timezones
- fixed-precision money representation
- currency code validation
