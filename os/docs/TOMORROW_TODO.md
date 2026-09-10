# TinkerOS — Master TODO / Tomorrow's Queue
*(Saved session state, 2026-09-09)*

## Completed Today
1. **Dust-dislodger fan-shake is spec-gated** (`kernel/tinker/dust_dislodger.c`): `run` is
   refused until `calibrate`/`rpm` CALCULATE the fan: rated ceiling, RPM-per-PWM slope,
   stall-floor +10% margin, resonance-safe pulse ceiling `(max_rpm/60)/3`, trough-safe
   amplitude cap; pulse/amplitude auto-clamped to the envelope on run; vmlinux link verified.
2. **os: kernel-GameMode hook** (`os/system/tinker-gamemode-hook.sh`): Feral GameMode
   `[custom] start/end` → `/proc/tinker/gamemode` `on <tgid>`/`off`; gamemode-setup installs it.
3. **Searchie: `timeline` command** (per-day event counts + latest fingerprints); 53 checks.
4. **ISO build complete + bootable**: rootfs squashfs (8.6 GB), casper vmlinuz (our bzImage,
   14.8 MB) + initrd, BIOS `isolinux.bin` (GRUB i386-pc core, initrd is baked into linux.mod
   on GRUB 2.06) + UEFI `efi.img`; El Torito BIOS/UEFI verified; `finalize` mode added;
   fixed root-owned dir writes + `-V` xorriso option. `TinkerOS-v1.2.iso` ~8.9 GB.
5. **Dual Source License v1.0** (`LICENSE`, README updated): Option A public / Option B
   private-source, no fee; kernel subtree keeps GPL-2.0 (COPYING); baked into the OS image.

## TODO for Tomorrow
1. **Publish ISO to SourceForge FRS** (`os/publish-iso.sh`, needs `SF_USER` + key registered
   on the SF account): `SF_USER=aghoshpratheesh os/release.sh` for automated releases.
2. **Rebuild branded ISO**: Plymouth animated splash + GRUB branded background baked in;
   world-gating (WORLDS=game|hack|secure|all); ISO size reduced (~1-2 GB savings).
3. **TIO/TUI polish**: markov chain completion phrases for the overlay; `markov` regression.
4. **Kernel: crash-safe gamemode reap DONE** (boost clears if the boosted process died).

## TODO for Tinker AI (Siri-like assistant)
1. **TinkerAI: answer anything** — train/retrieve answers for any question using a local
   knowledge base + web fallback; needs a local LLM or retrieval-augmented generation (RAG)
   pipeline; not maximum depth like Claude — just correct answers 90%+ of the time.
2. **TinkerAI: app connections** — pre-connected to all OS apps (browser, terminal, editor,
   file manager, calendar, email, notes, media player); user can `tinker-ai connect <app>`
   or `tinker-ai disconnect <app>`; each connection gives the AI access to that app's
   data/state/context.
3. **TinkerAI: rich display** — cards, links, multiple fonts, sizes, colors, styles in the
   response UI; uses a terminal/markdown renderer with ANSI colors + optional zenity/graphical
   overlay for rich formatting.
4. **TinkerAI: productivity hooks** — auto-suggest next actions, schedule reminders, draft
   emails, summarize documents, generate code, brainstorm ideas; all from within the TinkerOS
   desktop (Ctrl+Alt+Gr or voice activation).