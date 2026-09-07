# Aether Workspace — TinkerOS (first-party)

Zero-knowledge AES-256-GCM encrypted workspace. Offline-first sync, native
local automations. No cloud backdoors, no telemetry, no account for local use.

Adopted into TinkerOS as a first-party, pre-installed app. Bundled source is
the upstream Aether Workspace project, maintained inside this tree under
`os/apps/apps/aether-workspace`.

## Run

| mode | command |
|------|---------|
| dev   | `bun dev`   |
| build | `bun build` |
| preview | `bun preview` |

## Vault model

- AES-256-GCM via WebCrypto; PBKDF2-derived key from your password + salt.
- Master lock hash = salted SHA-256 (verification only, never the key).
- Sync token is user-generated and never leaves the user's devices.