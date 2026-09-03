# TinkerOS — MASTER FEATURE TODO (the huge one)

This is the definitive, exhaustive master list of EVERY feature built or
planned for TinkerOS across the entire project. The user asked for a
genuinely huge todo list (150+ entries). It is organized by category.

Status legend:
- [D]  = User-space implementation DONE (in `os/`)
- [K]  = Kernel C implementation DONE (inside the kernel source, `kernel/tinker/`)
- [P]  = Pending: needs kernel C implementation (the real mission)
- [B]  = Pending: needs to be baked into the .iso / installer

---

## A. Control Center & Shells (21)
- [D] Control Center GUI launcher (tinker-control-center.py, 8 categories)
- [D] System category (15 features) in Control Center
- [D] Gaming category (15 features) in Control Center
- [D] Hardware category (15 features) in Control Center
- [D] Network category (10 features) in Control Center
- [D] Customization category (12 features) in Control Center
- [D] Security category (8 features) in Control Center
- [D] Apps category (10 features) in Control Center
- [D] Advanced category (14 features) in Control Center
- [D] Feature resolution pipeline (run_feature across search paths)
- [D] Terminal history recorder (tinker-term-history)
- [D] Tinker Cowork (tinker-cowork, shared workspaces)
- [D] Game Console mode (tinker-game-console)
- [D] Enterprise mode (tinker-enterprise)
- [D] Marketplace / app store (tinker-market-gui)
- [D] Account / Tinker ID (tinker-id)
- [D] Hardware cert (tinker-hardware-cert)
- [D] Onboarding wizard (tinker-onboard)
- [D] Community site (mkdocs)
- [D] Brand tooling (tinker-brand)
- [P] Kernel-backed control interface (/proc/tinker -> Control Center status)

## B. System category (27)
- [D] adaptive-power-grid.sh
- [D] audio-clarity.sh
- [D] auto-updates.sh
- [D] backup-restore.sh
- [D] bluetooth-manager.sh
- [D] context-aware-adaptation.sh
- [D] context-aware.sh
- [D] digital-twin.sh
- [D] fast-boot.sh
- [D] feature-manager.sh
- [D] flatpak-support.sh
- [D] gamemode-setup.sh  [K partially: gamemode.c]
- [D] gaming-meta.sh
- [D] gpu-config.sh
- [D] hardware-detect.sh
- [D] init.sh
- [D] installer.sh
- [D] optimization-toggles.sh
- [D] password-manager.sh
- [D] password-monitor.sh
- [D] power-manager.sh  [K partially: energy_sched.c]
- [D] predictive-caching.sh
- [D] predictive-intelligence.sh
- [D] predictive-pre-caching.sh
- [D] rollback-recovery.sh
- [D] security-suite.sh
- [D] self-healing.sh
- [D] temporal-mapping.sh
- [D] temporal-resource-mapping.sh
- [D] update-system.sh

## C. Gaming category (15)
- [D] anticheat-helper.sh
- [D] audio-mixer.sh
- [D] controller-mapper.sh
- [D] discord-presence.sh
- [D] emulator-manager.sh
- [D] fps-monitor.sh
- [D] game-launcher.sh
- [D] game-replay.sh
- [D] game-saves-sync.sh
- [D] gif-recorder.sh
- [D] hardware-benchmark.sh
- [D] performance-graph.sh
- [D] screenshot-tool.sh
- [D] streaming-manager.sh
- [D] wine-manager.sh
- [D] NVIDIA driver install (gaming-support.sh install-nvidia)
- [D] Proton install (install-proton / install-ge-proton)
- [D] One-click gaming meta-package (gaming-meta.sh)
- [D] Feral GameMode service (gamemode-setup.sh)

## D. Hardware category (15)
- [D] display-calibration.sh
- [D] docking-station.sh
- [D] fingerprint-manager.sh
- [D] gpio-manager.sh
- [D] hdr-manager.sh
- [D] kvm-switch.sh
- [D] nfc-manager.sh
- [D] pen-stylus.sh
- [D] printer-manager.sh
- [D] scanner-manager.sh
- [D] serial-uart.sh
- [D] thunderbolt-manager.sh
- [D] touchscreen-manager.sh
- [D] usb-manager.sh
- [D] webcam-manager.sh
- [D] C backend: usb_control, fan_control, thermal_control, display_control,
      battery_control, msr_control, cat_control, fpga_control, 
      device_weights, audio_control

## E. Network category (10)
- [D] bandwidth-limiter.sh
- [D] dns-manager.sh
- [D] firewall-gui.sh
- [D] hotspot-manager.sh
- [D] mesh-network.sh
- [D] network-monitor.sh
- [D] proxy-manager.sh
- [D] speed-test.sh
- [D] vpn-manager.sh
- [D] wifi-analyzer.sh

## F. Customization category (12)
- [D] conky-stats.sh
- [D] cursor-themes.sh
- [D] desktop-effects.sh
- [D] font-manager.sh
- [D] grub-theme.sh
- [D] gtk-theme.sh
- [D] icon-packs.sh
- [D] login-theme.sh
- [D] qt-theme.sh
- [D] shell-theme.sh
- [D] wallpaper-manager.sh
- [D] window-animations.sh

## G. Security category (8)
- [D] biometric.sh
- [D] filevault.sh
- [D] findmydevice.sh
- [D] firewall.sh
- [D] gatekeeper.sh
- [D] password-manager.sh
- [D] privacy.sh
- [D] security-suite.sh
- [D] sip.sh (SIP / system integrity protection)
- [D] security.sh

## H. Apps category (13)
- [D] app-store.sh
- [D] battery-monitor.sh
- [D] file-manager.sh
- [D] gaming-mode.sh
- [D] gaming-support.sh
- [D] ocr-everywhere.sh
- [D] package-manager.sh
- [D] quick-note.sh
- [D] screen-recorder.sh
- [D] smart-clipboard.sh
- [D] software-center.sh
- [D] system-cleaner.sh
- [D] voice-commands.sh
- [D] tinker-ai.sh (AI assistant)

## I. Desktop category (24)
- [D] activity-monitor.sh
- [D] app-launcher.sh
- [D] clipboard-manager.sh
- [D] desktop-integration.sh
- [D] dock.sh
- [D] file-search.sh
- [D] gestures.sh
- [D] help-system.sh
- [D] multi-monitor.sh
- [D] night-mode.sh
- [D] notification-center.sh
- [D] screen-tools.sh
- [D] settings-gui.sh
- [D] setup-wizard.sh
- [D] shortcuts.sh
- [D] start-desktop.sh
- [D] system-monitor.sh
- [D] system-tray.sh
- [D] text-expander.sh
- [D] theme-manager.sh
- [D] tiling.sh
- [D] virtual-desktops.sh
- [D] widgets.sh
- [D] window-manager.sh

## J. Hardware-Tech: KERNEL IMPLEMENTATION TARGETS (29)  <<< THE REAL MISSION
These are the hardware/interaction "heavy code" concepts. K = kernel done,
P = pending kernel C implementation.
- [K] thermal-scheduler  (kernel/tinker/thermal_sched.c)  -- silicon thermal map
- [K] energy-scheduler   (kernel/tinker/energy_sched.c)   -- DVFS/energy hints
- [K] lifespan-doubler   (kernel/tinker/battery_life.c)   -- battery charge envelope
- [K] oled-shield        (kernel/tinker/oled_wear.c)      -- OLED burn-in wear
- [K] gamemode (kernel boost) -> kernel/tinker/gamemode.c
- [K] cache-tiering  -> kernel/tinker/cache_tiering.c  (CAT/MPAM ways profile)
- [K] coil-whine-killer -> kernel/tinker/coil_whine.c (PWM shift, consent-gated)
- [K] data-shredder  -> kernel/tinker/data_shredder.c (swap + privacy wipe)
- [K] dust-dislodger -> kernel/tinker/dust_dislodger.c (resonant fan pulse)
- [K] fpga-scaler    -> kernel/tinker/fpga_scaler.c   (precision scaling)
- [K] zero-latency-input -> kernel/tinker/zero_latency_input.c
- [K] cxl-memory     -> kernel/tinker/cxl_memory.c   (memory pool registry, opt-in)
- [K] dvfs-shaver    -> kernel/tinker/dvfs_shaver.c   (micro V/F shaving)
- [K] hardware-dna   -> kernel/tinker/hardware_dna.c  (fingerprinting)
- [K] neural-audio   -> kernel/tinker/neural_audio.c  (enhancement DSP)
- [K] neural-superres-> kernel/tinker/neural_super_res.c
- [K] predictive-prewarm -> kernel/tinker/predictive_prewarm.c
- [K] predictive-render  -> kernel/tinker/predictive_render.c
- [K] ray-traced-audio   -> kernel/tinker/ray_traced_audio.c  (ray-cast DSP)
- [K] remote-hardware-api-> kernel/tinker/remote_hardware_api.c
- [K] sdgpu         -> kernel/tinker/sdgpu.c   (software-defined GPU plane)
- [K] smart-power-grid  -> kernel/tinker/smart_power_grid.c
- [K] adaptive-display  -> kernel/tinker/adaptive_display.c
- [K] unified-memory    -> kernel/tinker/unified_memory.c
- [K] unified-control-plane -> kernel/tinker (all modules under /proc/tinker)
- [K] hardware-tuning   -> kernel/tinker/hardware_tuning.c
- [K] finance-audit     -> kernel/tinker/finance_audit.c  (audit hooks)
- [K] cross-app-automation -> user-space (OS abstraction layer; kernel proc interface available)
- [P] AI workload scheduling -- predictive AI-native scheduler (deep core-scheduler rewrite)

## K. AI & Intelligence (5)
- [D] voice-assistant.sh (os/ai)
- [D] voice-engine.sh (os/ai)
- [D] train.py / inference.py / generate-dataset.py (os/ai)
- [D] predictive-intelligence.sh
- [P] AI-native kernel scheduler (predictive)

## L. Installer / ISO / Packaging (10+)
- [D] installer.sh / iso-builder.sh / iso-builder-pro
- [D] build/tinker-build.py + build/tinker-build
- [D] kernel-build/build-kernel.sh
- [D] systemd units: tinker-backup, tinker-cleanup, tinker-desktop,
      tinker-heal, tinker-monitor, tinker-power, tinker-update + timers
- [D] grub.cfg (os/boot)
- [D] tinker.conf / optional-features.conf (os/system)
- [D] hardware.conf / packages.conf / profiles.conf (os/data)
- [D] profiles: hardware-db.sh, user-profiles.sh
- [P] Build genuine TinkerOS .iso from the modified kernel tree
- [P] Bake all kernel/tinker features + Control Center into the ISO
- [P] Ship modified kernel source + ISO to GitHub

## M. Network / Connectivity extensions (os/network) 
- [P] Additional network kernel modules based on session work

## N. Kernel infra (kernel/tinker) — SUPPORTING
- [K] Core /proc/tinker interface + status (tinker.c)
- [K] Shared header tinker_core.h
- [K] Kconfig (TINKER_FEATURES + 5 suboptions)
- [K] Makefile wiring into core-y
- [P] Wire gamemode boost into the realtime scheduler path
- [P] Wire thermal hints into select_task_rq logic
- [P] Wire energy hints into cpufreq governor
- [P] Wire OLED dim into backlight driver
- [P] Wire battery envelope into power_supply charger limits

---

## TOTALS
- User-space done: ~217 shell scripts + 24 Python tools
- Kernel C done: 27 modules (all hardware-tech targets + core infra),
  all compiling into built-in.a
- Pending kernel C: AI-native scheduler (deep core rewrite) + supporting
  wirings into scheduler/cpufreq/backlight/power_supply
- Pending packaging: ISO build + GitHub ship
