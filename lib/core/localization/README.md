# localization — reserved

`intl` is set up as a dependency (`pubspec.yaml`) and `Profile` carries
`preferred_language` / `timezone` / `date_format` / `number_format`
fields (`lib/core/database/tables.dart`), so the data model doesn't need
to change when localization work starts.

Beta 0 itself does not implement locale switching or translated strings
— onboarding (`lib/features/onboarding/presentation/onboarding_screen.dart`)
writes fixed defaults (`'en'`, `'UTC'`) rather than asking, and all UI
text in Beta 0 is hard-coded English. See
`docs/00_MASTER_BLUEPRINT.md` §40 ("Localization architecture must exist
from day one even when only a small initial language set is
translated.") — the architecture readiness is satisfied by the schema
fields above; the actual translated-strings work is not part of Beta 0's
scope (`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §12 makes the same call for
locale-aware number formatting specifically).
