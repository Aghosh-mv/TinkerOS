# TinkerOS — PROJECT MEMORY (do not delete; read at session start)

This file exists so the project's true origin and goal survive context
compaction. If you are an agent resuming work here, READ THIS FIRST.

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
