# Database Schema — V2 Core

This schema describes the logical model. Local Drift/SQLite and server PostgreSQL may use implementation-specific representations while preserving the same financial rules.

## profiles

- id
- user_id nullable for local-only profile
- display_name
- home_country
- current_country
- home_currency
- living_currency
- preferred_language
- timezone
- date_format
- number_format
- created_at
- updated_at

## currencies

- code (ISO 4217 where applicable)
- display_name
- symbol
- minor_units
- is_active

Never assume all currencies use two decimal places.

## accounts

- id
- user_id/profile_id
- name
- type
- currency_code
- opening_balance
- is_active
- created_at
- updated_at
- deleted_at

Current balance should be derived/reconciled from deterministic transaction data rather than treated as an unverified independent truth.

## categories

- id
- user_id/profile_id nullable for system category
- parent_id nullable
- type (expense/income/both)
- name
- icon
- sort_order
- is_system
- is_active

## transactions

- id (UUID)
- user_id/profile_id
- account_id
- destination_account_id nullable
- type (expense/income/transfer/refund/adjustment)
- amount
- currency_code
- category_id nullable
- merchant_id nullable
- note
- occurred_at
- receipt_id nullable
- recurring_transaction_id nullable
- group_id nullable
- created_at
- updated_at
- deleted_at
- sync_version
- sync_status

Rules:
- amount uses fixed-precision decimal or safe integer minor-unit representation
- transfers never count as income/expense
- original amount/currency are immutable financial facts unless the user edits the transaction

## transaction_exchange_rates

- id
- transaction_id
- base_currency
- quote_currency
- rate
- converted_amount
- provider
- provider_timestamp
- fetched_at
- is_manual

Historical snapshots are never replaced just because a newer market rate exists.

## transaction_items

- id
- transaction_id
- description
- quantity
- unit_price
- line_total
- category_id nullable
- confidence nullable

## merchants

- id
- normalized_name
- display_name
- country nullable
- default_category_id nullable

## receipts

- id
- transaction_id nullable
- local_image_path nullable
- object_storage_key nullable
- ocr_text nullable
- merchant_text nullable
- detected_date nullable
- detected_currency nullable
- detected_total nullable
- confidence
- status
- created_at
- deleted_at

## receipt_items

- id
- receipt_id
- raw_text
- normalized_name
- quantity nullable
- amount
- category_id nullable
- confidence

## budgets

- id
- user_id/profile_id
- name
- period_type
- start_date
- end_date
- currency_code
- total_limit nullable
- rollover_enabled
- is_active

## budget_categories

- id
- budget_id
- category_id
- limit_amount

## goals

> **Beta 1 Task 3 divergence:** the section below is the original
> aspirational "V2 Core" design. What actually shipped in schema version
> 3 is `savings_goals` (see `lib/core/database/tables.dart` and
> `docs/14_DECISION_LOG.md` ADR-022): `id`, `profile_id`, `name`,
> `target_amount_minor_units`, `currency_code` (permanently anchored,
> never `target_currency` conversion/FX), `target_date` (nullable,
> calendar-date-only, never a genuine instant), `created_at`,
> `updated_at`, `deleted_at` (soft delete), `sync_version`/`sync_status`.
> There is no `goal_type`, `priority`, `contribution_frequency`,
> `recommended_contribution` (pace is *derived*, never stored —
> `SavingsGoalCalculation.recommendedDailyContribution`),
> `motivation_enabled`, or `streak_enabled` column — none of that is in
> Beta 1's scope. `status` is likewise derived, never a stored column —
> see `SavingsGoalStatus`.

- id
- user_id/profile_id
- name
- goal_type
- target_amount
- target_currency
- target_date nullable
- priority
- contribution_frequency nullable
- recommended_contribution nullable
- motivation_enabled
- streak_enabled
- status
- created_at
- updated_at

The target is anchored to target_currency and must not drift with FX.

## goal_contributions

> **Beta 1 Task 3 divergence:** what actually shipped is
> `savings_goal_contributions` (ADR-022): `id`, `goal_id`,
> `amount_minor_units`, `currency_code` (duplicated from the parent goal
> at write time, always required to match it -- never a differing
> contribution currency, so there is no conversion snapshot to preserve),
> `contributed_at` (a genuine UTC instant), `created_at`, `deleted_at`
> (soft delete, contribution-level only -- deleting a contribution never
> cascades from/to its parent goal), `sync_version`/`sync_status`. There
> is no `account_id` or `note` column, and a contribution never creates a
> `transactions` row.

- id
- goal_id
- account_id nullable
- amount
- currency_code
- contributed_at
- note nullable

If the contribution currency differs from the goal currency, preserve a conversion snapshot.

## savings_streaks

> **Beta 1 Task 3 divergence:** not built. No streak table or column
> exists anywhere in schema version 3 -- see ADR-022's "no speculative
> tables" scope note. This section remains aspirational.

- id
- goal_id
- cadence
- current_count
- best_count
- last_qualified_period

## savings_milestones

> **Beta 1 Task 3 divergence:** not built as a table. Milestones are
> derived, never persisted -- `reachedSavingsGoalMilestones` in
> `lib/features/goals/domain/savings_goal_milestones.dart` recomputes the
> 25/50/75/100 thresholds reached fresh from `saved`/`target` every time
> (ADR-022), so there is no `reached_at`/`acknowledged_at` to store or go
> stale.

- id
- goal_id
- threshold_percent
- reached_at nullable
- acknowledged_at nullable

## recurring_transactions

- id
- user_id/profile_id
- type
- amount
- currency_code
- frequency
- interval_value
- next_due_date
- category_id nullable
- account_id nullable
- auto_create
- reminder_enabled
- is_active
- created_at
- updated_at

## exchange_rates

> **Checkpoint 9.3 divergence:** the section below is the original
> aspirational design. What actually shipped in schema version 7 is
> `reference_exchange_rates` (see that section below, and
> `lib/core/database/tables.dart`/`docs/14_DECISION_LOG.md` ADR-025):
> `base_currency`, `quote_currency`, `rate` (TEXT, never REAL), `provider`,
> `observed_at` (renamed from `provider_timestamp` to match the domain
> field `ReferenceFxRate.observedAt`), `fetched_at`. There is no surrogate
> `id` column — the primary key is the composite `(base_currency,
> quote_currency)` pair itself, which is also what gives this table its
> "at most one row per ordered pair" uniqueness, rather than a separate
> index. `user_currency_pairs` and `rate_alerts` below remain
> unimplemented and aspirational.

- id
- base_currency
- quote_currency
- rate
- provider
- provider_timestamp
- fetched_at

Use a uniqueness/index strategy appropriate to provider + pair + timestamp.

## reference_exchange_rates

> **What actually shipped, schema v7 (Checkpoint 9.3).** See
> `lib/core/database/tables.dart`'s `ReferenceExchangeRates` class doc and
> `docs/14_DECISION_LOG.md` ADR-025 for the full rationale.

- base_currency
- quote_currency
- rate (full-precision decimal TEXT, never REAL/double — ADR-018's rule)
- provider
- observed_at (a genuine instant; when the provider says the rate was
  quoted)
- fetched_at (a genuine instant; when this row was cached — this is what
  freshness is measured against, never `observed_at`)

Primary key: the composite `(base_currency, quote_currency)` pair — the
only table in this schema using a composite key instead of a surrogate
`id`, because a cache row's identity IS the ordered pair (see ADR-025).
`(USD, JPY)` and `(JPY, USD)` are always independent rows; a write for one
never affects the other.

This table is a replaceable, freshness-based CURRENT market-rate cache
(ADR-011: "FX rates are reference data") populated and read only through
`DriftReferenceFxRateCache`/`ReferenceFxRateService`
(`lib/core/fx/reference_fx_rate_service.dart`). It is architecturally
independent of `transaction_exchange_rates` above: never joined to it,
never read from it, never written from it. No FX provider vendor
integration, no FX UI, and no automatic/background refresh exist yet —
see ADR-025.

## user_currency_pairs

- id
- user_id/profile_id
- base_currency
- quote_currency
- sort_order
- is_favorite

## rate_alerts

- id
- user_id/profile_id
- base_currency
- quote_currency
- operator
- target_rate
- enabled
- last_triggered_at nullable

Rate alerts may be introduced after the initial private beta.

## tags

- id
- user_id/profile_id
- name

## transaction_tags

- transaction_id
- tag_id

Tags are P1 and may ship after the private beta core.

## groups

- id
- owner_user_id/profile_id
- name
- type
- currency_code nullable

Shared permissions are later-stage; local project/trip grouping may reuse this concept first.

## notifications

- id
- user_id/profile_id
- type
- scheduled_at
- delivered_at nullable
- read_at nullable
- payload_json

## notification_preferences

- user_id/profile_id
- budget_alerts
- bill_reminders
- savings_reminders
- goal_milestones
- fx_alerts
- weekly_summary
- monthly_summary
- quiet_hours_start
- quiet_hours_end

## sync_events

- id
- device_id
- entity_type
- entity_id
- operation
- version
- occurred_at
- synchronized_at nullable

## audit_logs

- id
- user_id nullable
- event_type
- entity_type nullable
- entity_id nullable
- created_at
- metadata_redacted

## AI tables — later

- ai_conversations
- ai_messages
- ai_insights
- ai_recommendations

AI data must reference deterministic financial outputs rather than become the source of balances/totals.

## Core rules

1. Never use binary floating point for money.
2. Do not assume two decimal places for every currency.
3. Preserve original transaction currency.
4. Preserve historical FX snapshots.
5. Transfers do not count as spending or income.
6. Soft deletion/sync semantics must be deterministic.
7. Receipt OCR requires confirmation when confidence or validation is insufficient.
8. Goal target currency is stable.
