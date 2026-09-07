# Verification — September 6, 2026

Passed:
- TypeScript compilation and Vite production build.
- Real Electron window: first launch, empty workspace, task creation/completion, reload persistence, private memory, draft approval into notes, emergency pause, light/dark themes, narrow layout overflow check, no JavaScript runtime errors.
- Controlled HTTP model endpoint: connection test, actual desktop request/response, private memory excluded, pause blocks requests, remote unencrypted HTTP rejected.
- Packaged Apple Silicon macOS app: opens welcome and Today; opens a separate always-on-top Sidecar window.
- Visual inspection of dark Today, light Today, and narrow layout screenshots. Long activity text wrapping improved afterward.

Not verified against user accounts: Ollama/LM Studio installations, cloud provider credentials, provider billing/limits. No external integrations are implemented. The macOS build is unsigned and not notarized; it is intended for local use pending distribution hardening.

Run `npm test` for the functional desktop/provider checks. Run `node tests/package-smoke.mjs` after packaging for the native artifact check. Tests use temporary user data directories and fictional test inputs only; application workspaces start empty.
