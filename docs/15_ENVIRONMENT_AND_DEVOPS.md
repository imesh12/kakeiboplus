# Environment and DevOps

## Environments

```text
local
development
staging
production
```

## CI pipeline

```text
Pull Request
 ↓
Lint
 ↓
Unit tests
 ↓
Integration tests
 ↓
Security scan
 ↓
Build
 ↓
Deploy staging
 ↓
Smoke tests
```

## Production

```text
Mobile
 ↓
CDN / API Gateway
 ↓
FastAPI
 ↓
PostgreSQL
Redis
Object Storage
Workers
AI Gateway
Monitoring
```

## Secrets

Use a dedicated secret manager in production.

Never commit:

- API keys
- database passwords
- signing keys
- OAuth secrets
- production credentials

## Backups

- automated database backups
- tested restore process
- object-storage versioning where appropriate
- disaster recovery runbook
