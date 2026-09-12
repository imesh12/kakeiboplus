# AI Financial Coach — Final Project Blueprint

**Version:** 2.0  
**Status:** Architecture Freeze Candidate — International-First Private Beta  
**Target:** Android + iOS first; web/admin and wearables later  
**Product type:** Global personal money companion: tracking, budgeting, savings motivation, receipt intelligence, multi-currency/FX, analytics, and later AI coaching

---

## 1. Executive Summary

AI Financial Coach is a privacy-first, offline-first **global personal money companion** for Android and iOS. It helps users **track money, save toward meaningful goals, understand spending, scan receipts, and manage daily life across currencies and countries**.

The product is especially useful for people who live, work, study, travel, or support family across borders. A user may have a **home country/home currency** and a different **current country/living currency**. The app can therefore show daily money in the currency used locally while also showing a familiar home-currency reference.

The primary product loop is:

```text
Capture money activity
        ↓
Organize it correctly
        ↓
Understand budget/cash flow
        ↓
Protect upcoming commitments
        ↓
Save toward goals
        ↓
See useful FX context
        ↓
Measure progress
        ↓
Receive deterministic insights
        ↓
AI explanation later
```

Examples:

- A Sri Lankan user living in Japan records a ¥1,200 lunch and optionally sees the current LKR reference equivalent.
- A Korean user living in Japan tracks expenses in JPY while keeping KRW as home currency.
- A user scans a receipt and confirms merchant, date, items, total, currency, and category before saving.
- A user creates a savings goal and receives a deterministic weekly contribution target and milestone feedback.
- A user checks JPY/LKR, JPY/KRW, JPY/NPR, QAR/LKR, KWD/INR, or any supported favorite FX pair inside the app.
- A user asks “Can I afford this?” only after the deterministic finance engine has calculated the factual numbers.

### Product principle

> **Track accurately. Save intentionally. Understand clearly. Use AI only after the financial truth is known.**

### International-first principle

The data model must not be built around one country, one currency, one decimal convention, or one receipt format. Multi-currency and localization are foundational architecture, not late add-ons.

---

## 2. Product Vision

### Vision

Become a trusted global money companion that helps people understand everyday finances wherever they live.

### Mission

Make personal finance:

- simple
- understandable
- motivating
- international-ready
- offline-friendly
- privacy-conscious
- accessible
- trustworthy

### Positioning

Traditional expense apps answer:

> “Where did my money go?”

This product should answer:

> “Where did my money go, how am I doing, what should I save next, and what does my money mean in the currencies I actually use?”

AI is an enhancement layer, not the product's financial foundation.

### Product pillars

```text
TRACK
Transactions, accounts, receipts, recurring money

SAVE
Goals, contributions, milestones, streaks, challenges

UNDERSTAND
Budgets, cash flow, analytics, deterministic insights

GLOBAL
Home/living currency, FX reference rates, locale, multilingual capture

COACH
AI explanations and recommendations after the core system is reliable
```

---

## 3. Goals and Non-Goals

### Product goals

1. Capture expenses with minimal friction.
2. Make receipt scanning fast and accurate.
3. Give users a beautiful financial dashboard.
4. Help users create measurable savings goals.
5. Turn spending history into understandable insights.
6. Deliver useful, configurable notifications.
7. Provide friendly AI coaching.
8. Support multiple currencies and locales.
9. Work offline for core transaction entry.
10. Protect sensitive financial data.
11. Build a foundation suitable for Google Play and Apple App Store release.
12. Support future bank integrations without making them mandatory.

### Non-goals for the first release

- Becoming a bank.
- Holding customer funds.
- Executing investments.
- Providing regulated financial advice.
- Guaranteeing investment returns.
- Automatically making financial decisions without user confirmation.
- Connecting to every bank in the world on day one.

---

## 4. Product Principles

1. **User control first**
2. **AI assists; user decides**
3. **Automation over typing**
4. **Explain recommendations**
5. **Never shame users**
6. **Privacy by design**
7. **Offline-friendly**
8. **Accessible UI**
9. **Reliable calculations**
10. **Human-readable financial language**
11. **Progress over perfection**
12. **Small actions beat overwhelming advice**

---

# 5. Target Platforms

## Phase 1

- Android
- iOS

## Phase 2

- Web dashboard
- Admin portal
- Apple Watch
- Wear OS

## Phase 3

- Desktop companion
- Family web experience
- Additional regional integrations

---

# 6. Target Users

### Persona A — Student

Needs:

- low-cost budgeting
- simple expense entry
- daily limits
- savings goals

### Persona B — Salaried employee

Needs:

- salary planning
- recurring bills
- monthly budgets
- savings automation guidance

### Persona C — Family

Needs:

- shared budgets
- family goals
- permissions
- child allowance tracking

### Persona D — Freelancer

Needs:

- irregular income
- tax-related categorization
- business/personal separation
- cash-flow forecasting

### Persona E — Traveler

Needs:

- multi-currency
- trip budgets
- receipt capture
- offline transactions

### Persona F — International resident / migrant worker / student

Needs:

- home currency + living currency
- quick reference FX rates
- expenses shown in both familiar and local currency
- savings goals for family, travel, education, remittance planning, or major purchases
- multilingual/localized UI
- reliable offline use
- receipt capture across countries
- clear timestamps and FX data sources

---

# 7. Core Feature Map

## Finance

- Accounts
- Wallets
- Cash
- Cards
- Income
- Expenses
- Transfers
- Recurring transactions
- Bills
- Subscriptions
- Categories
- Tags
- Merchants
- Attachments

## AI

- Financial Coach
- Spending Analyzer
- Receipt Analyzer
- Goal Planner
- Budget Planner
- Forecast Agent
- Motivation Agent
- Notification Agent
- Monthly Report Agent
- Merchant Categorization
- Voice Expense Assistant
- Recommendation Engine

## Goals

- Savings goals
- Target amount
- Target date
- Monthly target
- Milestones
- Goal forecast
- Goal scenarios

## Budgeting

- Monthly budget
- Weekly budget
- Daily allowance
- Category budget
- Flexible budget
- Rollover
- Alerts

## Analytics

- Daily
- Weekly
- Monthly
- Yearly
- Category
- Merchant
- Spending trends
- Savings rate
- Cash flow
- Goal progress
- Financial health indicators

## Engagement

- Daily motivation
- Streaks
- Challenges
- Achievements
- Milestones
- Personalized notifications

## Capture

- Manual entry
- Receipt photo
- Gallery import
- Voice entry
- Share-to-app
- Future bank sync

## Global Money

- Home country
- Current country
- Home currency
- Living currency
- Favorite currency pairs
- Reference FX rates
- Historical FX snapshots
- Rate alerts
- Original transaction currency
- Locale/date/number formatting
- Localization-ready UI
- International receipt test matrix

---

# 8. Receipt Scanner — Flagship Feature

## User flow

```text
Tap Scan Receipt
      ↓
Camera
      ↓
Auto-detect receipt
      ↓
Crop / straighten
      ↓
Image quality check
      ↓
Image enhancement
      ↓
OCR
      ↓
Merchant extraction
      ↓
Item extraction
      ↓
Total validation
      ↓
Category prediction
      ↓
Duplicate check
      ↓
User confirmation
      ↓
Transaction saved
```

## Receipt image processing

- perspective correction
- rotation correction
- cropping
- brightness normalization
- contrast enhancement
- shadow reduction
- blur detection
- background cleanup
- receipt boundary detection

## OCR fields

- merchant
- address
- date
- time
- receipt number
- currency
- subtotal
- tax
- discount
- total
- payment method
- line items
- quantities
- unit prices

## Example

Input:

```text
Supermarket
Milk ¥220
Bread ¥180
Chicken ¥780
Rice ¥2,400
Tax ¥358
Total ¥3,938
```

Output:

```text
Merchant: Supermarket
Category: Groceries
Total: ¥3,938
Date: 2026-08-23

Items:
- Milk ¥220
- Bread ¥180
- Chicken ¥780
- Rice ¥2,400
```

## Accuracy rule

AI must never silently invent missing financial data.

If confidence is low:

```text
I found a possible total of ¥3,938.
Please confirm before saving.
```

---

# 9. AI Financial Coach

The AI should have access only to the minimum relevant financial context required for a response.

### Example

User:

> I want to buy a car.

AI:

```text
Great goal.

Target: ¥3,000,000
Current savings: ¥850,000
Remaining: ¥2,150,000

At your current average savings rate,
the estimated target date is May 2029.

If you save ¥20,000 more each month,
the target moves approximately 4 months earlier.
```

The system should show the assumptions behind calculations.

---

# 10. Goal System

Each goal contains:

```text
Goal ID
Name
Goal type
Target amount
Target currency
Current contributed amount
Target date
Priority
Contribution frequency
Recommended contribution
Contribution history
Milestones
Streak state
Forecast
Motivation settings
Status
```

### Multi-currency goal rule

A goal is anchored to its **target currency**. If a user creates a goal for LKR 500,000, the target remains LKR 500,000. The UI may show today's approximate JPY/CAD/EUR equivalent, but exchange-rate movement must never silently redefine the goal.

Savings contributions must preserve the original contribution currency and the FX snapshot used when a converted view is needed.

### Goal examples

- New car
- House deposit
- Vacation
- Emergency fund
- Education
- Wedding
- Laptop
- Gaming PC

### Goal statuses

- active
- paused
- achieved
- cancelled

### Goal engine

Calculate:

- required monthly savings
- current savings rate
- projected completion
- optimistic scenario
- baseline scenario
- conservative scenario

Never present a forecast as guaranteed.

---

# 11. Budget System

Support:

- monthly budgets
- weekly budgets
- daily budgets
- category budgets
- custom periods
- rollover
- budget templates

Example:

```text
Food
Budget: ¥40,000
Spent: ¥28,500
Remaining: ¥11,500
Usage: 71%
```

---

# 12. Smart Spending Warnings

Warnings should be respectful.

Bad:

> You are terrible with money.

Good:

> Your restaurant spending is already 82% of this week's budget. If you planned another meal out, consider using a lower-cost option.

AI should allow:

- warning threshold
- quiet hours
- notification frequency
- categories to monitor
- coaching tone

---

# 13. Daily Motivation Engine

The system chooses messages using:

- time
- user goals
- recent spending
- budget status
- achievements
- streak
- preferred tone
- notification settings

### Morning

> Good morning! Your car goal is 61% complete. One small saving decision today keeps you moving forward.

### Evening

> You stayed within today's budget. Nice work.

### Overspending

> Today went above your usual spending. No problem—let's reset tomorrow.

No shame, fear, manipulation, or guilt.

---

# 14. Smart Notification Engine

Notification classes:

- morning greeting
- budget reminder
- spending alert
- bill reminder
- recurring payment
- goal milestone
- savings streak
- weekly report
- monthly report
- unusual spending
- subscription reminder
- challenge reminder

The user can disable every category.

---

# 15. Voice Expense Entry

Example:

> “I spent ¥1,200 on lunch.”

Pipeline:

```text
Speech-to-text
      ↓
Intent extraction
      ↓
Amount extraction
      ↓
Category
      ↓
Date
      ↓
Confirmation
      ↓
Save
```

If ambiguous:

> Did you mean ¥1,200 for lunch today?

---

# 16. AI Chat

Example prompts:

- Can I afford this?
- Why did I spend more this month?
- How can I save ¥30,000?
- Show my biggest spending category.
- What changed this week?
- Help me create a vacation goal.
- Create a 6-month savings plan.
- Explain my monthly report.

### Safety

The AI must distinguish:

- factual transaction data
- deterministic calculations
- estimates
- recommendations
- financial education

It must not fabricate transactions, balances, or account information.

---

# 17. Financial Health

Instead of a single opaque score, use explainable indicators:

```text
Budget discipline
Savings consistency
Goal progress
Recurring commitments
Cash-flow stability
Spending volatility
```

A composite score can be optional.

Every score must show:

- inputs
- date range
- methodology
- limitations

---

# 18. Analytics

Dashboard charts:

- income vs expenses
- savings trend
- spending by category
- merchant spending
- daily spending
- weekly spending
- monthly comparison
- annual trend
- spending heatmap
- goal progress
- cash flow
- recurring expense trend

### AI insight example

```text
Food spending increased 14%.

The largest change was restaurant spending
on Fridays and Saturdays.

Potential reduction:
¥6,000–¥10,000/month
if this pattern changes.
```

Recommendations must be estimates, not promises.

---

# 19. Subscription Manager

Detect recurring transactions.

Fields:

```text
Merchant
Amount
Frequency
Next expected date
Category
Active/inactive
Last used (if usage data exists)
```

Important:

The app should not claim a service is “unused” unless it actually has reliable usage data.

---

# 20. Gamification

Features:

- XP
- levels
- badges
- streaks
- challenges
- milestones
- savings achievements

Avoid gambling-like mechanics.

Example:

```text
7-day spending awareness streak

+100 XP
```

---

# 21. Family Mode

Future feature.

- family owner
- adult member
- child member
- viewer
- shared goal
- shared budget
- allowance

Privacy controls must prevent unnecessary exposure of individual transactions.

See `20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` for the full household/family sharing specification (V2 — not implemented).

---

# 22. Multi-Currency and FX

Multi-currency is a **core architecture requirement from Stage 1**.

### User currency model

Each profile may define:

```text
home_country
current_country
home_currency
living_currency
preferred_language
timezone
date_format
number_format
```

Example:

```text
home_country = LK
current_country = JP
home_currency = LKR
living_currency = JPY
```

### Supported behavior

- currency per account
- original currency per transaction
- home currency
- living currency
- favorite FX pairs
- reference FX conversion
- provider timestamp
- fetched timestamp
- historical exchange-rate snapshots
- rate history
- optional rate alerts
- travel transactions
- manual exchange-rate fallback
- offline use of last cached reference rate with visible staleness

### Historical transaction rule

Never rewrite historical transactions merely because today's exchange rate changed.

A converted transaction view must preserve:

```text
original_amount
original_currency
conversion_amount
conversion_currency
exchange_rate
exchange_rate_source
exchange_rate_timestamp
```

### FX display rule

The application must display rates as **reference rates**, including source and timestamp when available. It must not imply that the quote is the guaranteed rate a bank, card network, exchange shop, or remittance provider will execute.

### Currency precision rule

Do not assume all currencies have two decimal places. Currency metadata must support zero-, two-, three-, or other ISO minor-unit conventions. Examples include JPY/KRW (zero minor-unit display) and KWD (three decimals).

### FX provider rule

Do not scrape consumer search pages as the production FX data source. Use a provider/API with appropriate usage rights, timestamps, reliability, and redistribution terms.

---

# 23. Offline Mode

Core functions should work without internet:

- manual expenses
- manual income
- view cached dashboard
- view goals
- local receipt queue
- voice entry where local speech recognition is available

When online:

```text
local changes
      ↓
sync queue
      ↓
server
      ↓
conflict resolution
```

---

# 24. Data Model

Core entities:

```text
User
Profile
Device
Account
Wallet
Card

Currency
ExchangeRate
UserCurrencyPair
RateAlert
TransactionExchangeRate

Transaction
TransactionItem
Category
Tag
TransactionTag
Merchant
Receipt
ReceiptItem

Budget
BudgetPeriod
Goal
GoalContribution
SavingsStreak
SavingsMilestone
Challenge
Achievement

RecurringTransaction
Bill
Subscription

Group
GroupMember
Project

Notification
NotificationPreference

AIConversation
AIMessage
AIInsight
AIRecommendation

Attachment
SyncEvent
AuditLog
```

Not every entity must ship in the first private beta, but the core schema must leave room for international money, offline synchronization, recurring money, and savings motivation without destructive redesign.

---

# 25. Recommended Database

### PostgreSQL

Use PostgreSQL for server-side transactional data.

### Redis

Use for:

- caching
- rate limiting
- job queues
- temporary AI context
- notification scheduling

### Object storage

Use S3-compatible storage for:

- receipt images
- exported reports
- user attachments

Receipt images should have lifecycle policies and user-controlled deletion.

---

# 26. Mobile Technology

### Recommended

**Flutter + Dart**

Why:

- Android and iOS from one codebase
- strong UI performance
- mature ecosystem
- good animation support
- native integration
- easier solo/team development

### Mobile stack

```text
Flutter
Dart
Riverpod
GoRouter
Dio
Drift/SQLite
Secure Storage
Firebase Messaging
Crashlytics
```

Use local SQLite/Drift for structured offline-first transaction data.

---

# 27. Backend Technology

```text
Python
FastAPI
Pydantic
SQLAlchemy
Alembic
PostgreSQL
Redis
Celery/ARQ
S3-compatible storage
Docker
```

Use REST initially.

GraphQL can be evaluated later; it is not required for MVP.

---

# 28. AI Technology

Use a model abstraction layer rather than hard-coding one provider.

```text
AI Gateway
    ├── OpenAI
    ├── Local Ollama
    └── Future providers
```

AI tasks:

- conversational coaching
- classification
- extraction
- summarization
- recommendations
- notification copy

Do not use an LLM for arithmetic that can be calculated deterministically.

Example:

```text
Budget remaining
Savings rate
Goal date
Transaction totals
```

These should come from application code.

---

# 29. AI Architecture

```text
                  AI Gateway
                      |
                AI Orchestrator
                      |
       +--------------+--------------+
       |              |              |
   Coach Agent    Analysis Agent   OCR Agent
       |              |              |
   Goal Agent     Forecast Agent  Category Agent
       |              |              |
   Motivation     Notification    Report
```

### Deterministic-first principle

```text
Database
   ↓
Deterministic financial engine
   ↓
Statistical analysis
   ↓
AI interpretation
   ↓
User-facing explanation
```

The LLM must not become the source of truth for balances.

---

# 30. Recommendation Engine

Recommendations should contain:

```text
Recommendation ID
Type
Reason
Evidence
Estimated impact
Confidence
Priority
Expiration
User action
```

Example:

```text
Reason:
Restaurant spending increased 21%.

Estimated impact:
¥5,000–¥8,000 monthly savings.

Action:
Set a weekend restaurant budget.
```

---

# 31. AI Memory

Store structured preferences rather than indiscriminately storing conversations.

Examples:

```text
preferred_currency
goal_priority
notification_preference
coaching_tone
budget_period
```

Sensitive financial information should be minimized and protected.

Users should be able to clear AI memory.

---

# 32. API Structure

```text
/api/v1/auth
/api/v1/users
/api/v1/accounts
/api/v1/transactions
/api/v1/categories
/api/v1/merchants
/api/v1/receipts
/api/v1/budgets
/api/v1/goals
/api/v1/analytics
/api/v1/insights
/api/v1/fx
/api/v1/recurring
/api/v1/sync
/api/v1/ai
/api/v1/notifications
/api/v1/subscriptions
/api/v1/reports
/api/v1/settings
```

API requirements:

- versioning
- authentication
- authorization
- pagination
- idempotency
- validation
- rate limiting
- audit logging

---

# 33. Mobile Folder Structure

**Superseded by ADR-016 (see `14_DECISION_LOG.md`).** The Flutter project
root is the repository root itself — there is no `mobile/` wrapper
directory. This repository is a single mobile application, so the extra
nesting a `mobile/` package would imply (as if this were one app among
several in the repo) adds no value and was dropped.

The authoritative `lib/` layout is:

```text
lib/
├── app/                       # MaterialApp bootstrap, theming
├── core/
│   ├── database/               # Drift AppDatabase, tables, migrations
│   ├── finance/                # deterministic finance engine (pure Dart)
│   ├── money/                  # Money value type, parsing, rounding policy
│   ├── currency/                # Currency metadata + registry
│   ├── routing/                 # GoRouter configuration
│   ├── localization/            # intl setup, supported locales
│   └── errors/                  # Result/Failure types
│
├── features/
│   ├── onboarding/
│   ├── accounts/
│   ├── categories/
│   ├── transactions/
│   ├── dashboard/
│   ├── budgets/                 # reserved — Beta 1
│   ├── goals/                   # reserved — Beta 1
│   ├── fx/                      # reserved — Beta 2 (schema-ready only)
│   ├── receipts/                # reserved — Beta 3
│   ├── recurring/                # reserved — Beta 1/5
│   └── settings/
│
├── shared/
│   ├── widgets/
│   └── theme/
│
└── main.dart
```

Each `features/<name>/` follows an internal `data/ domain/ presentation/`
split. Reserved feature directories that have no Beta 0/1 implementation
yet contain only a short `README.md` stating which roadmap stage builds
them, rather than empty placeholder folders kept "for appearance."

`core/security/` and `core/sync/` are intentionally *not* created until a
feature actually needs them (Stage 6 for sync; whenever PIN/biometric/auth
material first requires secure storage) — see `CLAUDE_PROJECT_INSTRUCTIONS.md`
("Do not accumulate unused packages") and ADR-016.

---

# 34. Backend Folder Structure

```text
backend/
└── app/
    ├── main.py
    ├── config/
    ├── api/
    ├── auth/
    ├── database/
    ├── models/
    ├── schemas/
    ├── repositories/
    ├── services/
    ├── finance/
    ├── ai/
    ├── ocr/
    ├── notifications/
    ├── analytics/
    ├── reports/
    ├── workers/
    ├── storage/
    └── tests/
```

---

# 35. AI Folder Structure

```text
ai/
├── gateway/
├── orchestrator/
├── agents/
│   ├── coach/
│   ├── receipt/
│   ├── categorization/
│   ├── spending/
│   ├── goal/
│   ├── budget/
│   ├── forecast/
│   ├── motivation/
│   ├── notification/
│   └── report/
├── prompts/
├── schemas/
├── evaluators/
├── guardrails/
└── tests/
```

---

# 36. Documentation Structure

```text
docs/
├── 00_MASTER_BLUEPRINT.md
├── 01_PRODUCT_VISION.md
├── 02_REQUIREMENTS.md
├── 03_USER_PERSONAS.md
├── 04_USER_JOURNEYS.md
├── 05_APP_FLOW.md
├── 06_SCREEN_SPECIFICATION.md
├── 07_UI_UX.md
├── 08_DESIGN_SYSTEM.md
├── 09_FEATURES.md
├── 10_RECEIPT_OCR.md
├── 11_VOICE.md
├── 12_AI_ARCHITECTURE.md
├── 13_AI_AGENTS.md
├── 14_AI_PROMPTS.md
├── 15_RECOMMENDATION_ENGINE.md
├── 16_NOTIFICATION_ENGINE.md
├── 17_GOALS.md
├── 18_BUDGETS.md
├── 19_ANALYTICS.md
├── 20_DATABASE.md
├── 21_API.md
├── 22_MOBILE_ARCHITECTURE.md
├── 23_BACKEND_ARCHITECTURE.md
├── 24_SECURITY.md
├── 25_PRIVACY.md
├── 26_OFFLINE_SYNC.md
├── 27_TESTING.md
├── 28_DEVOPS.md
├── 29_MONITORING.md
├── 30_MONETIZATION.md
├── 31_STORE_RELEASE.md
├── 32_MARKETING.md
├── 33_ROADMAP.md
└── 34_DECISIONS.md
```

---

# 37. UI Design Direction

The app should feel:

- premium
- calm
- modern
- friendly
- trustworthy
- lightweight

Avoid:

- spreadsheet-like screens
- excessive charts
- financial jargon
- aggressive red warnings
- clutter
- too many buttons

Use:

- cards
- large numbers
- progressive disclosure
- subtle animation
- accessible typography
- clear hierarchy
- friendly illustrations

---

# 38. Main Navigation

For the private beta, use five primary destinations:

```text
Home
Activity
+ Add
Goals
Profile
```

The central add action opens:

```text
Expense
Income
Receipt
Transfer
Goal Contribution
```

Currency conversion and FX favorites should be reachable from Home and Profile/Tools without requiring a permanent bottom-navigation tab.

AI should not occupy a primary navigation tab in the private beta. It can be added later when sufficient reliable financial data exists.

---

# 39. Main Dashboard

```text
Good morning 👋

Financial Overview

Balance
Income
Expenses

Today's Budget

Goal Progress

AI Insight

Spending Breakdown

Recent Transactions

Quick Actions
```

Dashboard should be customizable.

---

# 40. Onboarding

Ask only what is necessary.

Private-beta onboarding:

1. Welcome
2. Current country
3. Home country
4. Living currency
5. Home currency
6. Preferred language
7. Main intent: Track / Save / Both
8. Optional monthly income
9. Optional first savings goal
10. Privacy and local/cloud preference
11. Optional receipt/camera permission
12. Notification preference

Defaults should be inferred where safe, but every country/currency setting must remain editable.

Do not force:

- bank connections
- AI permissions
- receipt scanning
- cloud synchronization
- detailed demographic information

Localization architecture must exist from day one even when only a small initial language set is translated.

---

# 41. Error Handling

Examples:

OCR failure:

> I couldn't read this receipt clearly. Try taking a photo in brighter light.

Network failure:

> You're offline. Your expense is saved and will sync later.

AI unavailable:

> Your transaction data is still available. AI insights will return when the service is available.

Never lose a transaction because an AI service failed.

---

# 42. Security Architecture

- TLS everywhere
- encrypted secrets
- secure token storage
- short-lived access tokens
- refresh-token rotation
- device/session management
- rate limiting
- input validation
- audit logs
- least-privilege access
- encrypted backups
- secure file URLs
- receipt deletion
- account deletion

---

# 43. Privacy

Privacy should be a product feature.

User controls:

- AI data usage
- receipt retention
- analytics consent
- notification preferences
- cloud backup
- AI memory
- account export
- account deletion

The privacy policy must accurately reflect actual implementation and regional requirements.

---

# 44. Financial Safety

The application is a financial wellness tool.

AI should:

- explain calculations
- identify assumptions
- provide educational information
- avoid guarantees
- avoid fabricated financial facts
- encourage professional advice for regulated/high-stakes situations
- never claim certainty about future markets

For bank integrations, follow applicable provider, platform, and regional requirements.

---

# 45. Testing Strategy

## Unit

- transaction calculations
- budgets
- goals
- currency conversion
- forecasts
- notification rules

## Integration

- API
- database
- OCR pipeline
- AI gateway
- sync

## UI

- onboarding
- expense entry
- receipt scan
- dashboard
- goals
- AI chat

## AI evaluation

Test:

- extraction accuracy
- hallucination
- category accuracy
- recommendation quality
- safety
- prompt injection resistance
- consistency

## Performance

- startup time
- receipt processing
- API latency
- database queries
- battery usage

---

# 46. Observability

Track:

- API latency
- error rates
- OCR confidence
- AI latency
- AI cost
- notification delivery
- sync failures
- crash-free sessions
- database health

Never log sensitive financial values unnecessarily.

---

# 47. Analytics and Product Metrics

Primary metrics:

### Activation

Percentage of new users who create their first transaction.

### Retention

D1 / D7 / D30.

### Goal adoption

Percentage creating a savings goal.

### Receipt usage

Percentage using receipt scanning.

### AI engagement

AI conversations per active user.

### Savings behavior

Self-reported or calculated savings improvement where data supports it.

### Notification effectiveness

Delivered → opened → action taken.

---

# 48. Monetization

## Free

- manual expenses
- basic budgets
- basic goals
- basic analytics
- limited receipt scans
- limited AI

## Premium

- unlimited receipt scanning
- advanced AI coach
- advanced analytics
- unlimited goals
- smart forecasts
- advanced reports
- family features
- cloud backup
- advanced customization

Avoid intrusive advertising because it conflicts with the trust position.

---

# 49. Store Release

## Google Play

Prepare:

- application ID
- signing keys
- privacy policy
- data safety declaration
- screenshots
- feature graphic
- app icon
- content rating
- store description
- support URL
- account deletion flow

## Apple App Store

Prepare:

- bundle ID
- certificates
- provisioning
- App Store metadata
- privacy nutrition labels
- screenshots
- age rating
- support URL
- privacy policy
- account deletion

Store requirements change over time; verify current requirements before release.

---

# 50. Development Phases

## Phase 0 — Architecture Freeze

- update blueprint to international-first V2
- freeze core money model
- freeze currency precision rules
- define offline/sync identifiers
- define private-beta telemetry and privacy

## Phase 1 — Core Money Engine

- Flutter foundation
- Drift/SQLite
- local profile
- accounts
- categories
- income
- expenses
- transfers
- local transaction history
- deterministic money calculations
- multi-currency data model
- currency metadata

## Phase 2 — Daily Money Experience

- dashboard
- budgets
- savings goals
- goal contributions
- milestones
- basic analytics
- transaction search/filter
- home/living currency display

## Phase 3 — FX Engine

- FX provider integration
- cached reference rates
- favorite pairs
- converter
- timestamps/source
- historical snapshots
- historical transaction conversion rule
- optional basic rate history

## Phase 4 — Receipt Intelligence

- camera
- receipt detection
- OCR
- image enhancement
- merchant/date/currency/total extraction
- confirmation UI
- duplicate detection
- multilingual test corpus

## Phase 5 — Recurring Money and Motivation

- recurring bills/income
- upcoming commitments
- notifications
- savings streaks
- milestones
- lightweight challenges
- deterministic smart insights

## Phase 6 — Cloud and Multi-Device

- authentication
- encrypted cloud backup
- synchronization
- conflict handling
- multi-device sessions
- receipt storage controls

## Phase 7 — AI Coach

- AI gateway
- coach
- spending explanations
- goal planner explanations
- categorization fallback
- recommendations
- monthly summaries

## Phase 8 — Advanced

- family/shared groups
- deeper localization
- voice
- advanced FX alerts
- web dashboard
- CSV/bank imports
- regional integrations

## Phase 9 — Regulated/Partner Integrations

- bank integrations where supported
- remittance comparison partnerships where legally appropriate
- wearables
- external financial data

---

# 51. Private Beta / V1 Definition

The first friends-and-family build should prove daily usefulness, not feature count.

Core private-beta capability:

```text
Onboarding
Local Profile
Accounts
Manual Expense
Manual Income
Transfer
Categories
Transaction History
Dashboard
Budgets
Savings Goals
Goal Contributions
Multi-Currency Foundation
Home/Living Currency
FX Favorites + Converter
Reference FX Timestamp/Source
Receipt Scanner + Confirmation
Basic Recurring Bills
Settings
Privacy Controls
Offline Local Database
```

AI chat is **not required** for the first private beta.

A target of roughly **15–25 meaningful user-facing screens** is preferred over a broad 35–60 screen implementation. Empty/loading/error/offline states still count as required quality work.

Cloud login/sync may be introduced after local-first reliability is proven, unless multi-device testing specifically requires it.

---

# 52. Release Gates

Do not release until:

- transaction calculations are verified
- transfers never count as income or expense
- currency precision is verified for zero-, two-, and three-decimal currencies
- historical converted transaction values do not change with today's FX rate
- FX source/timestamp/staleness is visible
- offline entry is reliable
- sync is reliable
- receipt errors are recoverable
- authentication is secure
- account deletion works
- privacy documentation matches implementation
- notification controls work
- AI cannot invent balances
- crashes are below agreed threshold
- performance is acceptable
- store compliance is verified

---

# 53. Future Features

Potential future roadmap:

- bank aggregation
- open banking integrations
- smart bill negotiation partnerships
- family plans
- employer financial wellness
- travel mode
- financial education
- investment tracking
- debt payoff planner
- credit score integrations where legally and technically appropriate
- merchant price history
- household inventory
- receipt warranty tracker
- tax document organization

---

# 54. Important Product Recommendation

Do not start with the AI agent.

Build:

```text
Stage 1
Reliable international financial data model

↓

Stage 2
Deterministic financial engine

↓

Stage 3
Savings / budget / recurring-money behavior

↓

Stage 4
FX reference-rate engine

↓

Stage 5
Receipt/OCR pipeline

↓

Stage 6
Analytics/statistics

↓

Stage 7
Recommendation engine

↓

Stage 8
AI interpretation

↓

Stage 9
Conversational AI
```

This order prevents two expensive mistakes:

1. making the LLM the financial engine;
2. adding multi-currency after the transaction model is already difficult to change.

---

# 55. Definition of Done

A feature is complete only when:

- requirements are documented
- UI is implemented
- database changes are migrated
- API is implemented
- validation exists
- errors are handled
- offline behavior is defined
- analytics are defined
- tests exist
- security is reviewed
- documentation is updated

---

# 56. Final Product Architecture

```text
                    FLUTTER MOBILE APP
                    Android / iOS
                         |
                 Local Drift / SQLite
                         |
                 Deterministic Engine
             +-----------+-----------+
             |           |           |
        Tracking      Savings       FX Cache
             |           |           |
             +-----------+-----------+
                         |
                    Sync Layer
                         |
                    FastAPI API
                         |
        +----------------+----------------+
        |                |                |
   PostgreSQL       Object Storage     Scheduler
        |                |                |
   FX Service          Receipts       Notifications
        |                |
   FX Provider        OCR Pipeline
        |
   Analytics / Rules
        |
   AI Gateway (later)
        |
 AI providers / local models
```

### Architectural rule

A network, OCR, FX, or AI failure must never erase or corrupt a locally captured transaction.

### Deployment rule

Redis/workers may be added when workload requires them. The architecture can support scale without deploying every scale component for the first 10–50 testers.

---

# 57. Final Product Philosophy

The app should make users feel:

> “This app helps me understand and improve my money, wherever I live.”

Not:

> “This app asks me to maintain an accounting database.”

The strongest product combination is:

```text
Expense + Income Tracking
        +
Receipt Scanner
        +
Budget Planner
        +
Savings Goal + Motivation System
        +
Multi-Currency + FX
        +
Recurring Money
        +
Analytics
        +
AI Coach later
```

The competitive advantage should come from **frictionless capture + trustworthy calculations + motivating savings + international usability + clear explanations**.

---

# 58. Final Success Criteria

The project succeeds when a new user can:

1. Install the app.
2. Complete onboarding quickly.
3. Create a financial goal.
4. Add an expense in seconds.
5. Photograph a receipt and have it converted into a transaction.
6. See an understandable dashboard.
7. Understand where money is going.
8. Receive useful—not annoying—coaching.
9. See how today's behavior affects a future goal.
10. Continue using the app because it genuinely helps them save.

**North-star outcome:**

> **Users should become better at managing money because the app is part of their daily routine.**
