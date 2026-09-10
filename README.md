# 🦝 TinkerOS — Your Computer. Your Rules.

> A hardware-throughput desktop OS layered on a real Linux kernel
> (code inside the Linux code). Three isolated worlds: **HACK**, **NORMAL**,
> **GAME** — switch with `Space+Shift+1/2/3`.

---

## 📥 Download OS

| Option | Link |
|---|---|
| **Primary ISO (SourceForge Global CDN)** | [Download TinkerOS-v1.3.iso](https://sourceforge.net/projects/tinkeros/files/v1.3/TinkerOS-v1.3.iso/download) |
| **SHA256** | `82bd9012fdd21ad96f8b1dabc60992ca07928807a5fe07db393e58e01a1999b6` |

> The ISO is ~7.6 GB. Verify the SHA256 after download.

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

The TinkerOS distribution and its user-space layer are licensed under the
**Dual Source License, Version 1.0** (see `LICENSE`). You may choose either:

- **Option A — Public Source License** (use, modify, and sell freely; modified
  works must be published publicly under this License), or
- **Option B — Private Source-Sharing License** (use, modify, and sell freely;
  keep modifications private, sharing source with the original copyright
  holder upon reasonable request).

Neither option requires any license fee.

The upstream Linux kernel portions of this tree remain covered by `COPYING`
(GPL-2.0); modifications to the kernel itself are distributed under GPL-2.0 and
the Developer Certificate of Origin. Third-party software inside the OS keeps
its own licenses. See `Documentation/process/coding-assistants.rst`.
