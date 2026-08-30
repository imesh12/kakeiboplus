# AI Architecture

## Principle

AI is an interpretation and interaction layer. It is not the financial source of truth.

## Architecture

```text
Client
  ↓
API
  ↓
Financial Data Layer
  ↓
Deterministic Finance Engine
  ↓
Analytics / Recommendation Engine
  ↓
AI Gateway
  ↓
Specialized Agent
  ↓
Guardrails / Output Validator
  ↓
Client
```

## Agents

### Coach Agent

Answers user questions and explains data.

### Receipt Agent

Validates OCR and structures receipt information.

### Categorization Agent

Predicts transaction categories.

### Spending Agent

Finds behavior patterns.

### Goal Agent

Explains goal progress and scenarios.

### Budget Agent

Suggests budget adjustments.

### Forecast Agent

Explains deterministic/statistical forecasts.

### Motivation Agent

Creates personalized encouragement.

### Notification Agent

Chooses whether a notification is useful and writes copy.

### Report Agent

Produces monthly summaries.

## Model routing

Use a model abstraction layer.

```text
AI Gateway
 ├── Primary cloud model
 ├── Lower-cost model
 └── Local model
```

Route simple tasks to cheaper models and sensitive/offline tasks to local processing where practical.

## Guardrails

- no fabricated balances
- no fabricated transactions
- no fabricated bank data
- no guaranteed forecasts
- no hidden actions
- no autonomous financial transfers
- no manipulative language
- no unnecessary sensitive data in prompts
- validate structured outputs

## Deterministic calculations

The following must be calculated by application code:

- totals
- balances
- budget remaining
- savings rate
- transaction aggregation
- goal contribution
- goal projection inputs
- currency arithmetic

The AI explains results; it does not replace the calculation engine.
