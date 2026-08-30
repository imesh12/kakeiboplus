# Security and Privacy

## Threat model

Protect:

- account identity
- transaction history
- receipt images
- financial goals
- AI conversations
- notification tokens
- device sessions

## Controls

- TLS
- encrypted storage
- secure credential storage
- token rotation
- least privilege
- role-based access
- rate limiting
- audit logs
- secure file access
- dependency scanning
- secret scanning
- SAST
- DAST
- penetration testing before major release

## Mobile

Use platform secure storage for tokens and secrets.

Enable optional:

- biometric unlock
- app PIN
- session timeout

## AI privacy

Only send necessary context.

Example:

Instead of sending an entire transaction history, send:

```text
Relevant category:
Food

Relevant period:
Last 30 days

Relevant aggregate:
¥38,200

Relevant trend:
+14%
```

when the user only asks about food spending.

## User controls

Users must be able to:

- export data
- delete data
- delete receipts
- delete AI memory
- delete account
- control analytics
- control AI features
- control notifications

## Compliance

Before launch, conduct a region-by-region legal/privacy review covering the countries in which the app will be distributed. Do not assume one privacy policy satisfies every jurisdiction.
