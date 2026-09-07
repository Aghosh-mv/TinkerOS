# Nibra BetterLife

A personal, chat-centered Electron companion for your digital life. Public preview 1.1.

**[Desktop releases](https://github.com/Aghosh-mv/nibra-betterlife/releases)** · **[Account sign-in](https://nibra-betterlife.tinkerhub12.chatgpt.site/account)**

## Your conversation is the workspace

The default grey chat surface supports ordinary conversation and prepares real workspace changes. Approve a task, project, note, memory, budget update, focus session, or file save directly in chat. Detailed sections in the sidebar show the same data. The assistant receives conversation history and only the personal context you enable.

- Real model endpoints: Ollama, LM Studio, OpenAI-compatible, Anthropic, Google, custom HTTPS.
- Secure browser sign-in with ChatGPT, explicit device-code pairing, expiring server sessions and sign-out revocation. Nibra never receives your identity-provider password.
- Each account has a separate encrypted local workspace and separate model credentials. Device-local mode is also available. Account identity is global; workspace records do not sync between devices.
- Tasks, projects, notes/imports, editable/private memory, budget planning context, activity, focus sessions, and approval queue.
- Native resizable always-on-top Sidecar. Selected text files only; no background folder scanning.
- Grey dark/light appearance, keyboard navigation, native focus-trapping dialogs, responsive layout, reduced-motion support.

## First run

Download an artifact for your platform from Releases, open Nibra, and sign in or continue on this device. In Settings, enter your exact model ID and endpoint, save, and test. No model or paid inference subscription is bundled. Provider charges, if any, are determined by the provider you connect.

Enable Workspace context in chat when you want the assistant to consider your saved tasks, notes, non-private memories, and manually entered budget. Private memories stay excluded. File attachments are selected individually. Review model output for accuracy.

## Preview boundaries

This is a **public beta**, not a completed global production service. Installers are currently unsigned/unnotarized; platform security dialogs may prevent installation. Developer ID/Windows signing and notarization are not configured. CI produces platform-specific preview artifacts; available downloads are listed on Releases. Do not assume a build exists for a platform until its artifact is visible.

External email/calendar/bank integrations, screen reading, unrestricted computer automation, cloud workspace sync, built-in hosted AI, automatic financial tracking, and arbitrary shell execution are not implemented. The application makes no claim to know activity it cannot access. File writes require both a native destination choice and exact-content approval. Workspace changes require one-time approval. No messages are silently sent.

## Privacy and security

Account-service data: site-scoped user ID, display email/name, short-lived device codes, hashed expiring session tokens. Authentication is provided by the Sites platform’s Sign in with ChatGPT flow. Device codes expire after ten minutes; sessions after thirty days. The browser explicitly confirms each device.

Workspace data: encrypted at rest using Electron safeStorage under the account-specific profile directory. Secure OS storage must be available; plaintext Linux basic_text fallback is rejected. Data is not synchronized to the account service. Model credentials stay in the main process, encrypted separately. No credential is returned to the renderer.

Model requests intentionally log their exact prompt and selected context locally in Privacy Center. Cloud models process this information under their own policies. Local models do not inherently guarantee privacy. Export contains workspace content, not credentials. Deletion affects the current local workspace, not other devices. Signing out revokes the current session.

Electron runs with context isolation, sandboxing, no renderer Node integration, sender-validated narrow IPC, navigation restrictions, and a content security policy. The agent has an allowlist of action types; model output cannot directly call the operating system.

## Development

Node 24+ and npm. `npm ci`, `npm run build`, `npm run desktop`. `npm test` runs account-service, agent, and real Electron workflow checks. UI tests require a desktop session. `npm run build:service` adds the Workers-compatible account service. D1 schema is in `db/schema.ts`; generated migrations are in `drizzle/`.

Public releases belong to **Aghosh-mv/nibra-betterlife**. The GitHub Actions workflow builds preview packages on macOS, Windows, and Linux. Production signing requires the owner's signing credentials and a separate distribution-hardening pass.
