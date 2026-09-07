# Nibra BetterLife — TinkerOS (first-party)

Consent-based, local-first lifestyle agent command center: accounts, provider-
backed assistant, editable memory, reviews. No hidden monitoring, no fake
connected services.

Adopted into TinkerOS as a first-party, pre-installed app. Bundled source is
NIBRA, maintained inside this tree under `os/apps/apps/nibra-betterlife`.

## Run

| mode | command |
|------|---------|
| web dev   | `bun run dev`   |
| desktop   | `npm run desktop` (electron) |
| tests     | `node --test tests/` |

## Privacy posture

- local-first; DB via drizzle/sqlite; no telemetry.
- Assistant provider boundary is visible and user-chosen.
- No hidden monitoring (anti-reference, per PRODUCT.md).