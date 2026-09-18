# KakeiboPlus landing page

A prerendered Vite + TypeScript marketing site. No runtime packages, hosted assets, analytics, paid services, or animation framework are required.

## Development

- `npm ci`
- `npm run dev`
- `npm run lint`
- `npm run typecheck`
- `npm test`
- `npm run build`
- `npm run test:e2e`
- `node scripts/visual-review.mjs`

The browser suite uses locally installed Microsoft Edge (`channel: msedge`). The visual review command starts and closes its own Vite preview on port 4175. Test screenshots and traces live in ignored `artifacts/`.

`npm run build` generates `dist/` and prerenders the complete page into HTML. Primary content works without JavaScript. Interactive examples progressively enhance that HTML. Set `SITE_URL` to the deployment origin when building to generate canonical and absolute social-image URLs; no domain is invented.

## Components and data

- `src/render.ts`: shared static/development section composition.
- `src/sections.ts`: preserved header, currencies, FX, growth, companion, pricing, footer, and dialogs.
- `src/stories.ts`: hero, problem narrative, multilingual demo, phone gallery, trust, and final CTA.
- `src/components/phone.ts`: original HTML dashboards and seven screen concepts.
- `src/components/companion.ts`: replaceable original SVG dog, cat, rabbit, and bird concepts. Decorative scenes are hidden from assistive technology.
- `src/localization.ts`: planned-language metadata, label dictionaries, directionality, and `Intl` formatting. Financial examples retain the same underlying JPY amounts as the UI language changes.
- `src/config.ts`: pricing, store URLs, launch and legal destinations. Regional subscription prices are explicit configuration, never FX conversions.
- `src/style.css`: baseline styles; `src/premium.css`: product-pass styling and responsive composition.

## Motion

`src/motion.ts` uses IntersectionObserver, Web Animations, CSS transforms, and a single lightweight scheduling timer. The phone never disappears during localization; its labels and amounts transition independently.

- Automatic hero locale change: every 8 seconds, only while visible and unfocused.
- Manual language selection: pauses automatic changes for 30 seconds.
- Motion button: pauses automatic localization and decorative motion; manual controls continue working.
- Companion scheduler (`src/motion-policy.mjs`): 10-second initial calm period, at most one 7.2-second scene, at least 45 seconds between scenes. Each completed scene runs once per page visit. Direct companion interactions defer decoration.
- Hidden documents stop the timer. Offscreen CSS animation pauses; offscreen decorative actions are canceled. Reduced motion removes automatic localization, chase actions, floating and scroll translations.
- The phone gallery separates gently on desktop scroll. Mobile uses native horizontal snap scrolling, with the selected screen first. Reduced motion uses a static composition.

## Production integration points

- `src/fx.mjs`: replace `demoFxProvider` with a backend provider. All present quotes are illustrative. `rateDisclosure` only permits a live label when a quote is explicitly live and has valid `updatedAt` and `provider` fields. Display failures without stale results.
- `src/downloads.ts`: implement `DownloadStatsProvider.getStats()` with a real backend. It must return a verified nonnegative integer, source, and timestamp, or null. Loading/available/unavailable states are supported. With no provider, only “App launch coming soon” is shown. No fabricated total is shipped.
- `src/config.ts`: populate `signupUrl`, `stores.appStoreUrl`, `stores.playStoreUrl`, legal URLs, and finalized prices when available.
- All nine language examples remain `planned` in `src/localization.ts`; native-language review is still required.
- Animal art is original, temporary vector concept art. No third-party mascots or real banknote artwork are used.
- Current social art is an SVG hook. Supply a production raster social image for platforms that do not accept SVG before publishing.

The expense form is an in-memory demonstration. It sends nothing to a backend and does not persist after reload. Trust copy is limited to these verifiable preview behaviors.

## Baseline

Commit `27a220d` preserves the validated site before the product/animation pass. Generated files, dependencies, test reports, and local environment files are ignored.
