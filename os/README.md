# TinkerOS — The Hardware-Through-Code Operating System

> "A desktop Linux OS that lets you reshape hardware behavior entirely through software."

## What Makes TinkerOS Different

Most operating systems treat hardware as fixed. TinkerOS treats it as **malleable** — every fan curve, every GPU clock, every microphone gain, every LED color can be controlled, tuned, and optimized through code. Not just "settings menus" — real, programmatic hardware control.

---

## Core Features

### 130+ Control Center Features
A unified PyQt6 GUI that surfaces every system, gaming, hardware, network, customization, security, and app feature. All backed by shell scripts that read/write `/sys`, `/proc`, and device interfaces.

### 4 Novel Techniques
| Technique | What It Does |
|-----------|-------------|
| **PSI** (Predictive System Intelligence) | Predicts your next action based on temporal patterns and pre-adjusts system state |
| **TRM** (Temporal Resource Mapping) | Creates a "time map" of resource usage and forecasts future needs |
| **CSS** (Context-Aware System Adaptation) | Detects WHAT you're doing (gaming/working/resting) and auto-adapts ALL parameters |
| **PFA** (Predictive Pre-Caching) | Learns file access patterns and pre-loads files you'll likely need |

### Mobile Companion Protocol
WebSocket server (`ws://<desktop-ip>:8766/ws`) that lets your phone:
- **Remote control** — volume, media, sleep, shutdown
- **File transfer** — send files between phone and desktop
- **Second screen** — extend your desktop to your phone
- **Notification mirroring** — see desktop notifications on your phone
- **QR pairing** — instant connection via QR code

---

## Novel Hardware Technologies

### Software-Defined GPU (SDGPU)
Simulates GPU rendering entirely in software using CPU vector extensions (AVX-512/NEON). Intercepts OpenGL/Vulkan calls via `LD_PRELOAD` and routes them to a CPU compute pipeline. Includes neural upscaling for software-rendered frames.

**How it works:**
- Detects CPU SIMD capabilities (AVX-512, AVX2, NEON)
- Creates `LD_PRELOAD` shim to intercept GL/Vk calls
- Routes rendering to parallel CPU compute (2 shader-units per core)
- Neural upscaler enhances software-rendered frames
- Display controller hardware scaler does final output

### Neural Audio Engine
AI-powered real-time audio enhancement that runs entirely on CPU:
- **RNNoise** recurrent neural network for noise cancellation (<5ms latency)
- **De-reverb** via spectral subtraction + neural network
- **Spatial audio** HRTF-based 7.1.4 virtualization
- **Speaker protection** with thermal monitoring
- **10-band parametric EQ** with adaptive presets

### Adaptive Display
Intelligent display processing that makes any screen look better:
- **MEMC** (Motion Estimation Motion Compensation) — interpolate 30fps to 60/120fps
- **Dynamic gamma** — auto-adjust contrast based on content
- **Predictive refresh rate** — boost Hz before scroll/gaming, drop for desktop
- **HDR emulation** — tone-mapping for SDR displays (simulated 1000 nits)
- **Night light** — automatic blue filter after sunset

### Remote Hardware API
Control your desktop hardware from your phone:
- **WebSocket server** at port 8767 with API key authentication
- **QR code pairing** for instant connection
- **Endpoints:** GPU toggle, fan curves, CPU governor, brightness, audio EQ, LED RGB, sleep/reboot, real-time stats
- **Security:** API key required, local network only, rate-limited

### Zero-Latency Input Pipeline
Bypass X11/Wayland entirely for input processing:
- **Direct evdev** — read input from kernel device files
- **<1ms latency** (vs ~16ms through X11)
- **1000Hz poll rate** for gaming responsiveness
- **Raw mouse input** — no acceleration, no smoothing
- **1:1 tracking** for competitive gaming

### Hardware DNA Profiling
Fingerprint your specific hardware and auto-apply optimal configs:
- **Auto-detect** CPU, GPU, RAM, disk, motherboard, BIOS
- **Community profiles** — share and download configs for your hardware
- **Optimal settings** per hardware combo (governor, scheduler, swappiness)
- **One-click apply** — instant optimization for your exact system

### Neural Super Resolution
AI upscaling for any window, even without a GPU:
- **Lightweight CNN** upscaler (no PyTorch needed)
- **2x-4x upscaling** of any application window
- **<16ms latency** per frame (real-time capable)
- **Edge-enhancement** for sharp results
- Works on desktop apps, games, video — everything

### Predictive Pre-Rendering
Render frames before you need them:
- **Scroll prediction** — extrapolate scroll velocity, pre-render next viewport
- **Mouse prediction** — linear extrapolation of cursor path
- **Window switch** — pre-render recently-used windows in background
- **3-frame buffer** — effective latency <5ms (perceived instant)
- **256MB cache** of pre-rendered frames

### Unified Hardware Control Plane
A single API that abstracts ALL hardware control:
- **28 endpoints** covering CPU, GPU, memory, storage, display, audio, input, network, thermal, power, USB, LEDs, camera, battery
- **4-tier permission model** (read-only → user consent → admin → root)
- **Real-time monitoring** of all hardware states
- Any application can request hardware changes through the API

### Smart Power Grid
Schedule tasks by electricity price/availability:
- **Peak/off-peak detection** (default: peak 17:00-21:00)
- **Task queue** — defer heavy tasks (compiling, rendering) to off-peak
- **Battery priority** — optimize for battery health
- **Solar integration** — schedule when solar output is high

### Unified Contextual Memory
A local-only, offline indexing engine that connects ALL your data:
- **Indexes:** files, emails, calendar events, browser history, images (OCR), notes, chat exports
- **Cross-reference search** — "Find that blue jacket my brother emailed me about last month, and show me the calendar event for the day we discussed it"
- **Entity extraction** — automatically finds people, places, organizations
- **Temporal connections** — links items that happened close in time
- **Timeline view** — chronological view of everything
- **SQLite database** — fast, local, no cloud dependency
- **Privacy guarantee:** 100% local, zero network, zero cloud

### Data Shredder (Nuclear Privacy Button)
One-click privacy wipe that scrubs your entire digital footprint:
- **8-step shred process:** backup → randomize MAC → obfuscate HW ID → deploy dummy telemetry → clear caches → flush DNS → clear swap → truncate logs
- **Preserves active sessions** — browsers, documents, running apps stay open
- **Restore command** — undo everything if needed
- **Audit logged** — every shred is recorded
- **Why it exists:** Major OS creators rely on telemetry. TinkerOS gives you the nuclear option they won't.

### GPU Phone Toggle
Turn your GPU on/off from your phone with a single tap:
- **API key in Settings** — generate a unique key for GPU control
- **Phone app sends command** — toggle GPU via WebSocket
- **Runtime PM** — suspends GPU at PCI level (not just driver)
- **NVIDIA + AMD** — works with both via `nvidia-smi -pm` and PCI power control
- **Why it matters:** No other OS lets you remotely toggle GPU power from your phone

---

## 14 Hardware Tuning Categories

| Category | Controls |
|----------|----------|
| **CPU** | Governor, core parking, turbo boost, C-states, frequency scaling |
| **GPU** | Power limit, clock speeds, undervolt, runtime PM, driver selection |
| **Thermal** | Fan curves, thermal zones, throttling thresholds, PWM control |
| **Power** | PCIe ASPM, SATA ALPM, USB autosuspend, C-states, NVMe power |
| **Display** | Brightness, color profiles, gamma, VRR, HDR, EDID override |
| **Audio** | ALSA mixer, PipeWire, spatial audio, microphone gain, EQ |
| **Input** | Keyboard repeat, mouse acceleration, touchpad gestures, Wacom |
| **Network** | WiFi power, ring buffers, offloads, WoL, interrupt coalescing |
| **Storage** | I/O scheduler, readahead, writeback, NVMe optimization |
| **Memory** | Swappiness, huge pages, KSM, zRAM, NUMA balancing |
| **Security** | TPM, Secure Boot, IOMMU, CPU mitigations, SMEP/SMAP |
| **USB** | Power budgeting, quirks, autosuspend, UAS vs USB-storage |
| **LED** | Keyboard backlight, RGB colors, patterns, OpenRazer |
| **Camera** | Exposure, gain, white balance, frame rate, autofocus |

---

## TinkerAI

On-device AI assistant with:
- **45+ tools** — system monitoring, file management, web search, code generation
- **6,205-document search AI** with 99% recall
- **JSON protocol** for Taskbar AI integration
- **`--serve` mode** for Control Center integration
- **Search AI** — semantic search across all indexed documents

---

## Architecture

```
Control Center (PyQt6 GUI)
    ├── 130+ Feature Scripts (os/apps/)
    ├── 4 Novel Techniques (os/system/)
    ├── Novel Hardware Tech (os/hardware-tech/)
    │   ├── SDGPU (Software-Defined GPU)
    │   ├── Neural Audio Engine
    │   ├── Adaptive Display
    │   ├── Remote Hardware API
    │   ├── Zero-Latency Input
    │   ├── Hardware DNA
    │   ├── Neural Super Resolution
    │   ├── Predictive Pre-Rendering
    │   ├── Unified Control Plane
    │   ├── Smart Power Grid
    │   └── Unified Contextual Memory
    ├── 14 Hardware Tuning Scripts (os/hardware-tech/hardware-tuning/)
    ├── Mobile Companion Protocol (os/mobile-companion/)
    └── TinkerAI (os/tinkerai/)
```

---

## C Hardware Backends (Real Driver Layer)

`os/hardware-tech/backend/` contains **compiled C drivers** that operate real
hardware registers — the "heavy code" underneath the shell features. Each is
**capability-probing**: it detects what *this specific machine* supports,
operates the real register/interface when it can, and degrades to a safe no-op
(never crashing, never misconfiguring) when it cannot.

```
make -C os/hardware-tech/backend   # builds bin/ with gcc (libc only, no network)
```

| Binary | Purpose | Fallback |
|--------|---------|----------|
| `msr_control` | MSR voltage/freq (IA32_PERF_CTL, APERF/MPERF, thermal) | sysfs cpufreq; 700–1350mV safe envelope |
| `cat_control` | Intel CAT L2/L3 cache-bit-mask partitioning | resctrl sysfs |
| `thermal_control` | per-core heat map (1000Hz capable) | /sys/class/thermal zones |
| `fan_control` | PWM speed + tach, `pulse` mode (resonant shaking) | ThinkPad ACPI / hwmon |

**Self-contained** MSR ioctls (no kernel headers), PIE-safe CPUID. Run with
`sudo` for raw access; binaries probe and fail gracefully at all times.

These backends are **preferred paths** wired into the shell features
(thermal-scheduler uses `thermal_control` for heat maps, cache-tiering uses
`cat_control` for L3 masks, dvfs-shaver uses `msr_control` for voltage, and
dust-dislodger uses `fan_control pulse` for resonant fan shaking), each
falling back to the prior Python/sysfs implementation.

---

## Consent & Liability Gate (Safe Hardware)

Because these features push hardware outside factory spec, **no raw write
happens without explicit user acceptance.** The shared gate lives in
`os/hardware-tech/lib/` and is wired into every physical-hardware script:

- `hardware-consent.sh` — shows a liability warning, requires the user to type
  `I UNDERSTAND`, logs acceptance to an **append-only local audit trail**
  (`~/.tinker/consent/`), TTL 90 days (interactive) / 1 year (`--yes`), and is
  revocable. **Without a TTY it auto-declines — fail-safe.**
- `backend-helper.sh` — C backend discovery + the consent-gated write helper
  that all hardware scripts source.

Safe reads, probes, and `init` run freely; only writes are gated.

---

## Privacy

**Everything runs locally.** No cloud. No telemetry. No tracking.
- Unified Contextual Memory: 100% local indexing
- Hardware DNA: profiles stored locally
- Remote API: local network only, API key auth
- TinkerAI: on-device inference

---

## License

MIT — Free for anyone to use, modify, and distribute.
