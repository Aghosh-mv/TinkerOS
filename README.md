# 🦝 TinkerOS — Your Computer. Your Rules.

> A hardware-throughput desktop OS layered on a real Linux kernel
> (code inside the Linux code). Three isolated worlds: **HACK**, **NORMAL**,
> **GAME** — switch with `Space+Shift+1/2/3`.

---

## 📥 Download OS

| Option | Link |
|---|---|
| **Primary ISO (SourceForge Global CDN)** | [Download ISO](https://sourceforge.net/projects/tinkeros/) |
| **Alternative Mirror (Internet Archive)** | [Download Mirror](https://archive.org/details/tinkeros) |
| **P2P Torrent (seed it!)** | [Download Torrent](https://archive.org/download/tinkeros/TinkerOS.iso.torrent) |

> 💡 Prefer torrents? Grab the .torrent above — seeding keeps TinkerOS
> cost-proof and un-ban-able. Star ⭐ the repo to support the project.

---

## The Three Worlds

- **HACK** (`Space+Shift+1` / `Ctrl+←`) — the world that does the most work
  **protecting the hacker** while **helping them hack more**. Only **Tor
  Browser** works here, and only **safe approved apps** may run.
- **NORMAL** (`Space+Shift+2` / `Ctrl+↑`) — the **most protected** world:
  it can still *find/hack the user*, but **cannot be hacked**.
- **GAME** (`Space+Shift+3` / `Ctrl+→`) — the **maximum-optimized** world
  for gaming (perf governor, low-latency scheduler, GPU/IO priority).

`Space+Shift+Esc` = **panic wipe**.

**Enter any world, press `Ctrl+Alt+Gr` to pop the preinstalled TinkerOS
agent (opencode) as a tiny agentic AI sir.**

---

## What ships in the box

- **Real kernel work** (inside the Linux code): 27 modules in `kernel/tinker/`
  (thermal_sched, gamemode, energy_sched, battery_life, oled_wear,
  cache_tiering, zero_latency_input, hardware_dna, sdgpu, …) wired into the
  real scheduler, cpufreq governor, backlight driver, and power supply paths.
- **45 territory tools** (18 HACK + 13 GAME + 14 SECURE), all launchable
  as `tinker-<tool>` commands.
- **Branded boot intro + login**: Plymouth splash (boot/reboot/shutdown),
  GRUB menu, and GDM greeter — all skinning real Linux, never replacing it.
- **User-space OS layer**: 278+ shell scripts, 25 Python tools, 10 C backends.

## Build

```sh
# kernel
make defconfig && make -j$(nproc) bzImage
# bootable ISO
./os/iso-builder.sh build
```

## World keybinds

```
Space+Shift+1  / Ctrl+Arrow-Left   -> HACK
Space+Shift+2  / Ctrl+Arrow-Up     -> NORMAL (most protected)
Space+Shift+3  / Ctrl+Arrow-Right  -> GAME  (max optimized)
Space+Shift+Escape                  -> panic wipe
Ctrl+Alt+Gr                         -> pop TinkerOS agent
```

## License

See `COPYING` (GPL-2.0) — TinkerOS builds on and is a modification of the
Linux kernel; licensing and the Developer Certificate of Origin apply.
See `Documentation/process/coding-assistants.rst`.
