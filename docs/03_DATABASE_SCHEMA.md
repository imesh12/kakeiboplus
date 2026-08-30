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

- id
- goal_id
- account_id nullable
- amount
- currency_code
- contributed_at
- note nullable

If the contribution currency differs from the goal currency, preserve a conversion snapshot.

## savings_streaks

- id
- goal_id
- cadence
- current_count
- best_count
- last_qualified_period

## savings_milestones

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

- id
- base_currency
- quote_currency
- rate
- provider
- provider_timestamp
- fetched_at

Use a uniqueness/index strategy appropriate to provider + pair + timestamp.

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
