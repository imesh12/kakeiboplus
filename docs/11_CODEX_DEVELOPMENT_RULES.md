# AI/Codex Development Rules

## Rule 1

Read the relevant documentation before changing code.

## Rule 2

Do not implement undocumented financial behavior.

## Rule 3

Never use an LLM for deterministic money calculations.

## Rule 4

Never expose secrets in source code.

## Rule 5

Every database change requires a migration.

## Rule 6

Every API change updates API documentation.

## Rule 7

Every feature requires tests.

## Rule 8

Offline behavior must be explicitly defined.

## Rule 9

Receipt extraction must be confirmable by the user.

## Rule 10

AI recommendations must identify assumptions when estimates are involved.

## Rule 11

Do not make broad refactors during feature implementation unless explicitly required.

## Rule 12

Keep commits small and logically grouped.

## Rule 13

Before marking a stage complete:

```text
Implement
→ Test
→ Review
→ Document
→ Verify
```

## Recommended task workflow

```text
Read blueprint
 ↓
Select one stage
 ↓
Create implementation plan
 ↓
Implement smallest slice
 ↓
Run tests
 ↓
Fix failures
 ↓
Update docs
 ↓
Generate stage report
 ↓
Commit
```
