# KakeiboPlus Dashboard Header & Brand Specification

**Document:** `docs/23_DASHBOARD_HEADER_BRAND_SPEC.md`  
**Product:** KakeiboPlus  
**Checkpoint:** U3 — Dashboard V1 Finalization  
**Status:** Approved visual direction for implementation  
**Primary scope:** Dashboard brand bar, greeting area, hero summary card, mascot treatment, color system, typography direction, and future theme extensibility

---

## 1. Purpose

This document defines the authoritative visual and interaction direction for the KakeiboPlus Dashboard header and hero area.

The Dashboard header is intended to become one of the most recognizable surfaces in the product. It should not look like a generic finance dashboard or a default Material Design screen. It should communicate the KakeiboPlus brand through a consistent combination of:

- premium rounded geometry,
- fresh teal / mint / emerald color language,
- friendly mascot warmth,
- calm and trustworthy financial presentation,
- modern typography,
- clear information hierarchy,
- strong accessibility,
- and future-ready presentation architecture.

This specification should be treated as the design source of truth for Dashboard header work in U3 and should continue to inform later UI polish, theme customization, mascot variants, seasonal skins, dark mode refinement, and release polish.

---

## 2. Product Brand Identity

### 2.1 Product name

**KakeiboPlus**

The name should be presented cleanly and confidently in the Dashboard brand area.

The visual presentation should feel modern and premium while retaining the approachable spirit of a household finance application.

### 2.2 Brand personality

KakeiboPlus should feel:

- fresh,
- friendly,
- premium,
- calm,
- encouraging,
- trustworthy,
- modern,
- financially clear,
- warm rather than corporate,
- polished without feeling sterile.

### 2.3 Brand statement

> **A soft-premium household finance app with fresh teal energy, friendly pet warmth, and calm financial clarity.**

This statement should guide visual decisions whenever multiple design directions are possible.

---

## 3. Dashboard Header Design Principle

The Dashboard header should use a **three-part premium structure**:

1. **Brand top bar**
2. **Greeting block**
3. **Financial hero summary card**

These parts should read as one coherent brand area rather than three unrelated widgets.

The header should feel elegant and emotionally warm before the user enters the denser financial sections below.

---

## 4. Header Information Architecture

### 4.1 Layer A — Brand top bar

The top row provides product identity and a small amount of navigation utility.

Recommended structure:

```text
┌─────────────────────────────────────┐
│ KakeiboPlus                  [icon] │
└─────────────────────────────────────┘
```

Possible right-side action:

- profile,
- account,
- settings,
- or another existing appropriate Dashboard action.

#### Rules

- Keep the bar compact.
- Do not make it excessively tall.
- Avoid multiple competing actions.
- Do not use the brand bar as a financial data surface.
- The KakeiboPlus wordmark/name should remain clearly legible.
- If a future brand mark / leaf mark is added, it should support the wordmark rather than replace it without a deliberate branding decision.

---

### 4.2 Layer B — Greeting block

The greeting area introduces warmth and personality.

Example English:

```text
Good morning!
Small steps make a brighter future.
```

Example Japanese:

```text
おはようございます！
小さな一歩で、もっと明るい未来へ。
```

The exact wording may be refined for natural localization, but the intended tone is:

- supportive,
- concise,
- positive,
- calm,
- not childish,
- not overly motivational,
- not sales-like.

#### Time-aware greeting

If the current app architecture already supports local-time-aware greeting without introducing unnecessary complexity, the greeting may vary:

- Good morning
- Good afternoon
- Good evening

Japanese should be localized naturally.

Do not add a new heavy time service solely for cosmetic greeting behavior unless already supported by the project architecture.

#### Greeting rules

- One primary greeting line.
- One short secondary line maximum.
- No long paragraph.
- No financial numbers in this area.
- Avoid excessive emojis.
- Avoid multiple chips/badges.
- The greeting should not compete visually with the hero amount.

---

### 4.3 Layer C — Financial hero summary card

The hero card is the visual centerpiece of the Dashboard header.

Recommended structure:

```text
┌─────────────────────────────────────┐
│ THIS MONTH                          │
│                                     │
│ ¥137,600                  [MASCOT]  │
│ remaining                           │
│                                     │
│ Income   ¥320,000                   │
│ Expense  ¥182,400                   │
└─────────────────────────────────────┘
```

The hero card should immediately communicate one useful monthly financial state.

---

## 5. Hero Metric Semantics

### 5.1 Do not expose Net Worth on Home

The Dashboard hero must **not** display Net Worth or a disguised equivalent.

The hero value must not imply:

- total assets,
- total wealth,
- total account balance,
- household net worth,
- or combined account holdings.

### 5.2 Preferred hero metric

Preferred V1 concept:

**Remaining this month**

Conceptually:

```text
Remaining = Current-month income - Current-month expense
```

The exact implementation must reuse the project's established financial rules and tested provider/repository/domain logic.

Do not reimplement financial truth inside the widget.

### 5.3 Supporting values

Supporting values may include:

- Income this month
- Expenses this month

These should remain visually secondary to the main hero amount.

### 5.4 Transfers

Transfers must follow the application's existing accounting rules and should not be treated as ordinary income or expense if current project semantics exclude them.

### 5.5 Zero and negative states

Examples:

**Positive remaining**

```text
¥137,600 remaining
```

**Zero**

```text
¥0 remaining
```

**Overspent / negative**

```text
-¥24,300
Over this month's income
```

The final wording should be localized naturally.

Color must never be the only signal for negative/overspent state.

---

## 6. Default Mascot

### 6.1 Production asset

Default mascot asset:

```text
assets/branding/pets/kakeiboplus_dog_default.png
```

This asset is part of the KakeiboPlus Dashboard brand presentation.

### 6.2 Mascot positioning

Default position:

- right side of hero card,
- vertically balanced with the main content,
- visually integrated with the gradient,
- not floating awkwardly outside the card.

### 6.3 Mascot rendering rules

The mascot must:

- preserve aspect ratio,
- preserve transparent background,
- never be stretched,
- never cover the main amount,
- never cover income/expense labels,
- remain visually readable at common phone sizes,
- be intentionally cropped only when required for composition,
- scale down before important financial text is compromised.

### 6.4 Semantics

The mascot is decorative unless a future product requirement gives it interactive meaning.

Recommended accessibility behavior:

- exclude decorative mascot descendants from redundant screen-reader semantics,
- preserve useful semantics for the hero card and financial values,
- avoid announcing visual-only decorative details.

### 6.5 Domain separation

Mascot asset paths must not be stored in:

- transactions,
- budgets,
- recurring rules,
- accounts,
- savings goals,
- or other financial/domain records.

Mascot selection belongs to presentation / branding configuration.

---

## 7. Future Mascot and Theme Variants

The Dashboard architecture should allow future visual skins without changing financial semantics.

Examples:

### Variant A — Teal Dog
- teal gradient,
- current dog mascot,
- default KakeiboPlus theme.

### Variant B — Pink Cat
- pink / coral gradient,
- cat mascot,
- softer playful theme.

### Variant C — Blue Bird
- sky blue / mint gradient,
- bird mascot,
- light calm visual feel.

### Variant D — Green Rabbit
- green / yellow gradient,
- rabbit mascot,
- growth / savings feel.

### Seasonal variants

Possible future examples:

- spring,
- summer,
- autumn,
- winter,
- New Year,
- sakura,
- holiday / celebration themes.

U3 should **not** implement a full theme marketplace or pet-selection feature.

It should only avoid architecture that makes those future variants difficult.

---

## 8. Fixed vs Variable Design Layers

A key architecture rule is to separate the permanent layout from changeable visual skins.

### 8.1 Fixed layer

The following should remain stable:

- KakeiboPlus brand identity,
- Dashboard information hierarchy,
- typography system,
- spacing system,
- card geometry,
- section order,
- hero content layout,
- financial semantics,
- accessibility behavior,
- icon sizing conventions.

### 8.2 Variable layer

The following may vary later:

- hero gradient,
- mascot image,
- decorative leaf/cloud shapes,
- accent color,
- optional seasonal decoration.

Conceptual model:

```text
KakeiboPlus Dashboard Header
        │
        ├── Fixed
        │    ├── structure
        │    ├── spacing
        │    ├── typography
        │    ├── semantics
        │    └── financial hierarchy
        │
        └── Variable
             ├── gradient
             ├── mascot
             ├── decorative accents
             └── theme skin
```

---

## 9. Core KakeiboPlus Color Language

The approved starting palette is inspired by the chosen visual reference and mascot direction.

### 9.1 Primary brand colors

| Token concept | Color | Usage direction |
|---|---:|---|
| Deep Teal | `#0F9E9A` | primary brand, darker hero gradient edge |
| Emerald Teal | `#19B7A5` | main brand surface, hero gradient |
| Mint Green | `#6ED6A8` | soft positive accent, supporting highlights |
| Soft Aqua | `#DDF6F3` | subtle backgrounds, low-emphasis brand surfaces |

### 9.2 Support colors

| Token concept | Color | Usage direction |
|---|---:|---|
| Dark Navy Text | `#18304A` | primary text on light surfaces |
| Soft Gray Text | `#6B7A8C` | secondary text |
| Card White | `#FFFFFF` | cards and clean content surfaces |
| Background Mist | `#F4FBFA` | soft page background |

### 9.3 Accent colors

| Token concept | Color | Usage direction |
|---|---:|---|
| Sunny Yellow | `#F6C44F` | small warm accent, caution/highlight when appropriate |
| Leaf Green | `#75C96A` | growth / positive accent |

---

## 10. Color Architecture Rules

Before introducing new constants, implementation must audit:

```text
lib/shared/theme/app_theme.dart
lib/shared/theme/app_theme_provider.dart
lib/shared/theme/app_theme_style.dart
lib/shared/theme/app_tokens.dart
lib/shared/theme/app_typography.dart
```

The goal is to integrate KakeiboPlus brand colors into the existing design-token/theme system.

Do not create an unrelated Dashboard-only color system if equivalent shared tokens already exist.

### Rules

- Centralize reusable colors.
- Avoid hardcoded duplicate hex values across multiple widgets.
- Preserve dark-theme compatibility.
- Preserve custom-theme compatibility where the app already supports it.
- Ensure sufficient contrast.
- Do not use color alone to communicate financial state.

---

## 11. Hero Gradient

Default hero gradient direction:

```text
#0F9E9A  →  #19B7A5
```

Optional subtle use of Mint Green may be used as a secondary highlight if it improves depth without reducing readability.

### Gradient goals

- fresh,
- premium,
- calm,
- clean,
- not neon,
- not overly glossy,
- not game-like.

### Hero foreground

Recommended:

- main amount: white,
- main labels: white,
- secondary text: accessible white variant / controlled opacity,
- positive micro-accent: mint/light green only where contrast remains sufficient.

Avoid placing low-contrast pale text directly over the brightest gradient area.

---

## 12. Page Background

The Dashboard body should use a soft, clean neutral that supports the hero card.

Preferred direction:

```text
Background Mist #F4FBFA
```

The actual implementation should respect the application's current theme architecture.

The brand hero should stand out without making every surface teal.

---

## 13. Premium Typography Direction

### 13.1 Desired typography personality

Typography should feel:

- clean,
- modern,
- premium,
- soft,
- highly readable,
- financially precise,
- friendly in English and Japanese.

### 13.2 Latin / numbers direction

Preferred:

1. **Plus Jakarta Sans**
2. **Inter**

The final implementation should audit current project typography before adding fonts.

### 13.3 Japanese direction

Preferred:

1. **Noto Sans JP**
2. **M PLUS 1p**

### 13.4 Typography architecture

If custom fonts are adopted:

- bundle for offline use,
- declare centrally,
- do not hardcode font names per Dashboard widget,
- integrate through shared typography/theme,
- ensure Japanese fallback works correctly,
- ensure currency symbols and financial numbers render clearly.

### 13.5 Financial numbers

Financial amounts require excellent legibility.

Where supported by the chosen font/Flutter implementation, prefer:

- stable numeral width / tabular numbers,
- strong weight contrast,
- clean decimal rendering,
- sufficient space for long values.

Examples:

```text
¥1,284
¥137,600
¥1,284,590
-$1,450.25
KWD 1,245.375
```

Do not assume all currencies use zero or two decimals.

---

## 14. Typography Hierarchy

Suggested visual hierarchy:

### App wordmark
- medium / semibold,
- not oversized.

### Greeting
- medium/semibold,
- friendly but restrained.

### Supporting greeting text
- regular,
- lower contrast than greeting.

### Hero label
- small/medium,
- high clarity.

### Hero amount
- largest financial text in the header,
- bold/semibold,
- high contrast.

### Hero supporting values
- smaller than hero amount,
- readable,
- aligned consistently.

The exact type sizes should reuse or extend shared typography tokens rather than creating random one-off values.

---

## 15. Geometry and Shape Language

KakeiboPlus should use a premium rounded visual grammar.

### Desired shape characteristics

- generous but controlled corner radius,
- clean cards,
- soft visual rhythm,
- predictable spacing,
- no random geometry.

### Audit existing shared components

Before adding new geometry values, inspect:

```text
AppCard
AppIconTile
AppFinanceListRow
AppSectionHeader
AppProgressBar
AppMoneyText
AppTokens
AppTypography
```

### Rules

- reuse existing radius tokens where appropriate,
- introduce new shared token only when necessary,
- avoid unrelated per-widget values such as 17px / 23px / 31px without reason,
- hero card may justify a larger radius than standard cards, but it should still belong to the same design system.

---

## 16. Spacing

The header should breathe.

Recommended principles:

- clear top margin,
- compact brand bar,
- moderate gap before greeting,
- moderate gap before hero,
- generous internal hero padding,
- controlled spacing between amount and supporting metrics.

Avoid:

- compressed layout,
- excessive empty vertical space,
- arbitrary spacing values,
- inconsistent horizontal padding with the rest of Home.

---

## 17. Responsive Behavior

The Dashboard header must work on:

- small Android phones,
- standard phones,
- larger phones,
- narrow test viewports,
- English,
- Japanese,
- increased text scale,
- long currency values,
- light theme,
- dark theme,
- supported custom themes.

### Priority rule on constrained widths

When space is limited:

1. preserve financial meaning,
2. preserve main amount,
3. preserve labels,
4. preserve controls,
5. reduce/reposition mascot,
6. reduce decorative elements.

Never clip the main financial amount in order to preserve mascot size.

### Mascot fallback behavior

Possible responsive strategies:

- scale mascot down,
- move mascot slightly lower/right,
- crop decorative lower body,
- reduce decorative leaf shapes,
- increase card height if appropriate,
- preserve text zone.

---

## 18. Dark Mode

Dark mode must preserve KakeiboPlus identity without simply copying the light theme unchanged.

### Requirements

- accessible contrast,
- premium rather than neon,
- mascot remains visually integrated,
- hero values remain instantly readable,
- surrounding cards remain visually distinct,
- dark background does not swallow the teal brand.

Potential direction:

- deeper teal hero,
- darker neutral page surface,
- controlled mint accents,
- off-white financial text.

Implementation should use existing dark-theme architecture rather than introducing a Dashboard-only dark mode.

---

## 19. Custom Theme Compatibility

If the app already supports custom theme behavior, the Dashboard should respect it.

However, KakeiboPlus brand identity should remain recognizable.

This means custom themes may alter:

- supporting surfaces,
- accents,
- possibly hero skin in the future,

but should not destroy:

- typography hierarchy,
- core layout,
- financial semantics,
- accessibility,
- mascot placement logic,
- component consistency.

---

## 20. Header Motion and Animation

U3 does not require animation.

If animation is added later:

- keep it subtle,
- no distracting mascot bounce loops,
- no continuously moving financial values,
- respect reduced-motion accessibility preferences where practical,
- animation should never delay financial information.

A static premium header is preferable to a flashy animated one.

---

## 21. Decorative Elements

Possible decorative language:

- soft leaf shapes,
- small cloud-like forms,
- subtle circles,
- abstract growth shapes,
- low-opacity background accents.

These must remain secondary.

Do not:

- crowd the hero,
- place decoration behind critical text without contrast control,
- use excessive gradients,
- imitate another app's proprietary visual composition directly.

---

## 22. Brand Reference Usage

The approved visual direction is inspired by the provided reference image.

Use the reference for:

- mood,
- color family,
- rounded geometry,
- mascot integration,
- visual warmth,
- compositional balance.

Do **not** copy:

- another product's logo,
- exact wording,
- proprietary character,
- exact screen composition,
- trademarked identity,
- unique branded graphics.

KakeiboPlus must have its own visual identity.

---

## 23. Dashboard Sections Below the Header

The header should visually transition into the functional Dashboard sections.

Recommended V1 order after the hero:

1. Budget snapshot
2. Upcoming payments / subscriptions
3. Savings goals
4. Recent activity

Possible high-level structure:

```text
Brand bar
Greeting
Hero summary
────────────
Budgets
Upcoming
Savings Goals
Recent Activity
```

The detailed implementation belongs to U3 Dashboard V1, but the header should provide a clear visual entry point to these sections.

---

## 24. U2 Financial Identity Reuse

The Dashboard must reuse the visual identity architecture already completed in U1/U2.

### Entry identity precedence

```text
1. Explicit service identity
2. Category identity
3. Safe generic transaction/recurring fallback
```

Do not create another independent Home-only icon resolution system.

Examples:

```text
Netflix
→ service identity

Restaurant
→ category identity

Legacy uncategorized expense
→ generic expense fallback
```

---

## 25. Currency Presentation

Currency code remains authoritative.

Examples:

```text
JPY
USD
LKR
EUR
GBP
KWD
```

A small country/region marker may be shown by `CurrencyBadge` where it genuinely helps identification.

### Rules

- currency ≠ country,
- region marker is secondary presentation,
- do not make flags authoritative,
- EUR remains neutral EU,
- shared/multi-country currencies must not falsely imply ownership by one country,
- do not place a flag beside every amount mechanically.

The hero may use normal money formatting without a CurrencyBadge if context is already clear.

---

## 26. Card-Network Presentation

Card-network identity is not a default Dashboard-header concern.

Do not show:

- Visa,
- Mastercard,
- American Express,
- JCB,

unless a genuine payment-instrument context exists on the Dashboard.

Do not fabricate official logos.

Use the existing `CardNetworkBadge` where appropriate elsewhere.

---

## 27. Accessibility

The header must remain fully understandable without:

- mascot recognition,
- color recognition,
- decorative imagery.

### Requirements

- meaningful hero semantics,
- useful amount labels,
- financial state expressed in text,
- no color-only state,
- adequate text contrast,
- text scaling safety,
- no clipped amounts,
- decorative descendants excluded from redundant semantics,
- controls retain sensible focus behavior,
- no semantics duplication caused by nested decorative widgets.

---

## 28. Localization

All user-visible Dashboard header strings must be localized.

Required:

```text
lib/l10n/app_en.arb
lib/l10n/app_ja.arb
```

Examples requiring localization:

- Good morning
- Good afternoon
- Good evening
- motivational/supporting message
- This month
- Remaining
- Income
- Expenses
- status text

Do not hardcode English strings in widgets.

Proper brand name remains:

```text
KakeiboPlus
```

unless a future branding decision explicitly changes it.

---

## 29. Empty / First-Use Behavior

The header must still feel intentional for a new user with no data.

Avoid showing a hero full of meaningless zeros without context.

Possible direction:

```text
This month
No activity yet

Add your first transaction to start your monthly snapshot.
```

The exact behavior should follow existing empty-state patterns.

The mascot can remain visible and friendly.

Do not convert the hero into a giant onboarding tutorial.

---

## 30. Partial Data States

The Dashboard may have:

- transactions but no budgets,
- budgets but no recurring items,
- recurring items but no goals,
- goals but no recent transactions.

The header should remain stable regardless.

The hero should not depend on budgets/goals/subscriptions being configured.

---

## 31. Error / Loading Behavior

Do not show raw exceptions in the hero area.

Use the app's existing loading/error architecture.

Preferred behavior:

- stable layout,
- minimal loading treatment,
- no large layout jump,
- clear retry/recovery if a real error occurs.

Because the app is local/offline-first, Dashboard read errors should be treated as local data errors, not as generic "network unavailable" unless a network-backed feature genuinely fails.

---

## 32. Performance

The header must remain cheap to render.

Avoid:

- repeated expensive calculations inside `build`,
- duplicate database queries,
- network lookup for visual identity,
- dynamic logo download,
- high-resolution unnecessarily large assets,
- multiple independent provider watches when one composed provider is more coherent.

The mascot should be appropriately sized/compressed for mobile use.

---

## 33. Offline-First Requirement

The Dashboard header must render completely offline.

Required offline-capable elements:

- mascot,
- colors,
- fonts if custom fonts are adopted,
- icons,
- category identity,
- service identity,
- hero text.

No network request may be required to render saved financial identity.

---

## 34. Testing Expectations

U3 tests should cover the Dashboard header behavior actually implemented.

At minimum:

### Visual/data behavior
- current-month income,
- current-month expense,
- remaining amount semantics,
- zero state,
- negative/overspent state if supported,
- no Net Worth surfaced,
- service identity reuse,
- category fallback,
- generic fallback.

### Layout
- populated header,
- empty-data header,
- small viewport,
- long amount,
- English,
- Japanese,
- text scaling.

### Theme
- light theme,
- dark theme,
- supported custom-theme compatibility where practical.

### Mascot
- asset renders,
- does not obscure text,
- no overflow,
- decorative semantics do not duplicate financial meaning.

---

## 35. Production Asset Registration

Before using the mascot, verify `pubspec.yaml`.

Preferred structure:

```yaml
flutter:
  assets:
    - assets/branding/pets/
```

Do not duplicate the same asset under multiple folders.

Do not rename the production file without updating this specification and all relevant references.

---

## 36. U3 Implementation Boundaries

U3 should implement the Dashboard V1 header and Dashboard data integration.

U3 does **not** implement:

- Net Worth on Home,
- full pet marketplace,
- pet-selection settings,
- remote pet downloads,
- cloud-based theme fetching,
- seasonal download engine,
- OCR,
- AI coaching/chat,
- Search/Filters/History,
- category-management redesign,
- full app-wide typography migration unless explicitly approved,
- final AG release polish.

---

## 37. Recommended U3 Header Structure

Reference structure:

```text
┌─────────────────────────────────────────┐
│ KakeiboPlus                      [icon] │
│                                         │
│ Good morning!                           │
│ Small steps make a brighter future.    │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ THIS MONTH                          │ │
│ │                                     │ │
│ │ ¥137,600                  [ DOG ]   │ │
│ │ remaining                           │ │
│ │                                     │ │
│ │ Income    ¥320,000                  │ │
│ │ Expense   ¥182,400                  │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

This is a conceptual layout, not a pixel-perfect requirement.

The actual Flutter implementation should adapt to:

- current shared components,
- theme tokens,
- localization,
- responsive constraints,
- and tested financial logic.

---

## 38. Visual Quality Checklist

Before U3 is considered complete, the Dashboard header should satisfy:

- [ ] KakeiboPlus branding is clearly visible
- [ ] Greeting feels warm and premium
- [ ] Hero amount is immediately readable
- [ ] Hero does not expose Net Worth
- [ ] Mascot is integrated naturally
- [ ] Mascot never obscures text
- [ ] Teal/mint palette feels coherent
- [ ] Dark mode remains premium
- [ ] Japanese layout is natural
- [ ] Large financial values do not clip
- [ ] Text scale does not break layout
- [ ] Empty state feels intentional
- [ ] Shared design tokens are reused
- [ ] No duplicate Dashboard-only theme system is created
- [ ] U1/U2 visual identity is reused
- [ ] Accessibility does not depend on color/image
- [ ] All assets render offline

---

## 39. Future Customization Direction

A future settings system may support:

```text
Dashboard Theme
├── Teal Dog
├── Pink Cat
├── Blue Bird
├── Green Rabbit
└── Seasonal
```

A future presentation model may conceptually contain:

```text
DashboardHeaderTheme
- id
- gradient token/key
- mascot key
- decorative style key
- accent token/key
```

This is a presentation concern only.

Do not persist raw asset paths as domain truth.

Prefer stable semantic identifiers if/when theme selection is implemented.

---

## 40. Final Design Rule

The Dashboard should remain recognizable as KakeiboPlus even if the app name is temporarily hidden.

Its signature identity should come from:

```text
fresh teal / mint color language
+
premium rounded geometry
+
friendly mascot warmth
+
dark navy typography
+
clear monthly financial hierarchy
+
consistent category/service visual identity
+
calm, trustworthy presentation
```

The goal is not to make the Dashboard decorative.

The goal is to make **financial information feel clear, approachable, premium, and uniquely KakeiboPlus**.

---

## 41. Implementation Instruction for Claude / Coding Agent

Before changing Dashboard code:

1. Read this specification completely.
2. Verify the current Git HEAD and working-tree status.
3. Inspect the existing Dashboard/Home implementation.
4. Inspect shared theme, token, typography, card, money, icon, category, service, and currency components.
5. Verify the production mascot asset: `assets/branding/pets/kakeiboplus_dog_default.png`.
6. Verify `pubspec.yaml` asset registration.
7. Explain how the existing architecture maps to this specification.
8. Reuse existing shared architecture before creating new abstractions.
9. Do not create a schema migration unless independently justified by actual Dashboard data requirements.
10. Do not stage or commit automatically.
11. Stop after U3.
12. Do not begin Checkpoint V.
