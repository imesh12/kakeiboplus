# Notification Engine

## Objective

Send notifications only when they are useful.

## Inputs

- current time
- timezone
- budget status
- goals
- spending patterns
- recent transaction activity
- upcoming bills
- user notification settings
- quiet hours
- notification frequency limits

## Notification priority

1. critical user-configured bill reminder
2. user-configured budget alert
3. goal milestone
4. useful insight
5. daily motivation
6. promotional content

Promotional content must never override financial alerts or quiet hours.

## Anti-spam rules

- daily maximum
- category cooldown
- duplicate suppression
- quiet hours
- user disable controls
- notification fatigue detection

## Tone

Friendly, concise, respectful.

Never shame.

Example:

> Your restaurant budget is 82% used this week. If you have another meal out planned, consider setting aside a lower-cost option.

## Scheduling

Use server scheduling for reliable reminders and local scheduling for offline-capable user-configured reminders where appropriate.
