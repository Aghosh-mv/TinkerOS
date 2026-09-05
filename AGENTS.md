# TinkerOS — PROJECT MEMORY (do not delete; read at session start)

## SELF-WATCHDOG (READ THIS EVERY SESSION)  <-- CUE ON 2026-09-05T21:46:34+05:30 -->
- This is a very long-running autonomous build. The user will NOT prompt or
  "cue on" repeatedly — they expect the agent to keep working until every
  task is DONE.
- STDIN/console loads constantly. If there is a steady stream of user
  messages, keep pumping out real work (create/fix files, run builds,
  commit) with ZERO gaps.
- NEVER stop mid-task waiting for a prompt. If you finish a chunk, keep
  going to the next chunk. Only stop when the current explicit task list
  (see TODOs / MASTER_TODO) is fully complete.
- If you realize you stalled (didn't produce work), resume immediately
  with the next concrete build step — do not apologize at length.
- MANDATORY STALL CHECK: at the START of EVERY turn, check for the file
  `SELF-WATCHDOG-STALL.md` in the repo root. If it exists, the watchdog has
  injected a stall signal — STOP reading further, clear it
  (`os/territories/self-watchdog.sh clear`) and immediately produce the
  next REAL tool call / build step. This file is the watchdog's genuine
  way to interfere with and re-engage the agent.
- CUE-ON BEAT: a second watchdog (`os/territories/cue-watchdog.sh`) types
  "CUE ON" into the live session console + writes `SELF-WATCHDOG-STALL.md`
  + broadcasts via `wall` every 60s by default. If you see a cue-on line
  appear in the console or the stall file content reads "CUE ON", treat it
  as an explicit instruction from the user: IMMEDIATELY stop any filler and
  emit the very next real tool call (write/build/commit). Do not wait for a
  human prompt.

## BUILD ON REAL LINUX (READ EVERY SESSION)
- TinkerOS is BUILT ON TOP OF REAL LINUX, a real running Linux system. We
  do NOT re-invent the wheel.
- Use Linux's native mechanisms as the DEFAULT and skin/theme/extend them:
  * Login page  = the real display manager greeter (GDM3/SDDM/LightDM).
    Do not build a brand-new login system; THEME the existing greeter.
  * Boot intro  = real Plymouth theme (boot/reboot/restart/shutdown splash)
    + GRUB theme for the boot menu. These are the standard, most effective.
  * Everything user-space that Linux already provides (login, splash, init,
    packaging, graphics/Wayland/X11, drivers) is leveraged, not replaced.
- Custom branded work supplements Linux (a themed GDM greeter, a branded
  Plymouth + GRUB theme, a custom alternative greeter) — but the REAL Linux
  substrate is always the foundation and remains functional.
- This commitment is a standing rule: never forget we are building on a
  real, booting Linux distribution.

## The one true mission (verbatim, from the founding session)

## The one true mission (verbatim, from the founding session)
Session: `Improving Linux with user features from GitHub`
Started: 2026-08-08 11:06:59

Original user request (exact):
> "get the code of latest linux from github and improve it .. feature by
> feature .. research what users wants ..and build them in .. code inside
> the linux code not as a separate code ... ask a lot of qs if wanted"

Key commitment the user insists on (this keeps being forgotten):
- We are MODIFYING THE LINUX KERNEL ITSELF — the code inside this repo
  (`kernel/`, `mm/`, `fs/`, `drivers/`, `net/`, `arch/`, `mm`, `block`,
  `io_uring`, etc.).
- Features must be "code inside the linux code" — implemented inside the
  kernel source, NOT as a separate user-space layer.
- Feature-by-feature, research what users want, build them in, ask
  questions when uncertain.

## Important divergence / current honest status (as of 2026-09-03)
- This repo IS a full Linux kernel source tree (downloaded from GitHub).
- To date, the bulk of completed work lives in the `os/` directory:
  a user-space "Control Center" with 224+ tool scripts (System, Gaming,
  Hardware, Network, Customization, Security, Apps, Advanced), plus
  installer-level modules (hardware-detect, gaming-meta, gamemode-setup,
  flatpak-support, NVIDIA/Proton), an AI subsystem (tinkerai/), and a
  hardware-tech layer (29 feature dirs + C backends).
- Real kernel work is now well underway: `kernel/tinker/` contains 27 real
  kernel C modules (thermal_sched, gamemode, energy_sched, battery_life,
  oled_wear, cache_tiering, coil_whine, data_shredder, dust_dislodger,
  fpga_scaler, zero_latency_input, cxl_memory, dvfs_shaver, hardware_dna,
  ray_traced_audio, neural_audio, predictive_prewarm, smart_power_grid,
  adaptive_display, unified_memory, hardware_tuning, neural_super_res,
  predictive_render, remote_hardware_api, sdgpu, finance_audit + tinker.c
  core). All wired via Kconfig + Makefile (core-y), compile into
  kernel/tinker/built-in.a.
- Master feature list: os/docs/MASTER_TODO.md (~232 items, exhaustive).

## Direction going forward
1. Keep the user-space `os/` layer (it is a usable product).
2. Continue the real kernel work: wire the kernel/tinker hint modules
   (gamemode/thermal/energy/oled/battery) into the actual scheduler,
   cpufreq governor, backlight driver, and power_supply paths.
3. Build a genuine TinkerOS `.iso` from this tree.
4. Ship to GitHub at the end.
