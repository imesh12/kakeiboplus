# goals — Beta 1 Task 3, hardened in Checkpoint S

Implemented. Savings goals, goal contributions, milestones, and the
Home dashboard's priority-goal card are all live -- see
`docs/14_DECISION_LOG.md` ADR-022 (the original schema/pace/milestones/
Home-selection design) and ADR-042 (Checkpoint S's audit-and-harden
pass: the double-submit fix and the additional regression coverage it
added; the architecture itself was already correct and needed no
redesign).

`goals` and `goal_contributions` from `docs/03_DATABASE_SCHEMA.md`
became `savings_goals`/`savings_goal_contributions` at schema version 3
(ADR-022) -- `savings_streaks`/`savings_milestones` were deliberately
NOT added as separate tables; milestone attainment is derived fresh
from `saved`/`target` on every read (`domain/savings_goal_milestones.dart`)
rather than persisted, and there is no streak feature in Beta 1's scope.

A goal's target currency stays anchored at creation and is never
FX-converted (ADR-013/ADR-022) -- `SavingsGoalRepository.updateGoal`
rejects any attempt to change it. Follows the same
`data/ domain/ presentation/`-shaped structure as `features/transactions/`,
adapted to this feature's actual repository/domain split
(`core/database/repositories/savings_goal*.dart` +
`features/goals/domain/` + `features/goals/presentation/`).
