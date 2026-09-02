# TinkerOS Hardware Backends (C)

Real compiled C drivers for TinkerOS hardware features. Each binary is
**capability-probing**: it detects what this specific machine actually supports,
operates the real hardware register/interface when it can, and degrades to a
safe no-op (never crashing, never misconfiguring) when it cannot.

## Build
```
make            # builds bin/ from src/ (gcc, no network, libc only)
make clean
```
Add `sudo make install` to place binaries in a system path, or run directly
from `bin/` with `sudo` for raw access.

## Binaries
- `msr_control`   - MSR voltage/frequency control (IA32_PERF_CTL, APERF/MPERF,
                    thermal status). Falls back to sysfs cpufreq. Never writes
                    outside 700-1350mV safe envelope without negotiation.
- `cat_control`   - Intel Cache Allocation Technology (L2/L3 CBM masks) via MSR
                    with resctrl sysfs fallback. Validates contiguous masks.
- `thermal_control` - Per-core heat map from MSR therm status, falls back to
                    /sys/class/thermal zones. Supports --continuous 1000Hz polling.
- `fan_control`   - PWM/tach control via hwmon sysfs (+ThinkPad ACPI fallback).
                    `set`, `ramped`, `pulse` (for dust-dislodger), `auto`, `read`.
- `display_control` - Backlight/DPMS control (oled-shield, adaptive-display).
                    Reads/writes real /sys/class/backlight brightness with max
                    scaling; `dim <frac>` applies OLED wear compensation.
- `battery_control` - Charge/health management (lifespan-doubler). Reads
                    status/capacity/voltage/current/temp/health from
                    /sys/class/power_supply; sets `charge_control_end_threshold`
                    (20-100% envelope) and `input_current_limit`/`charge_control_limit`
                    for trickle charging. Safe no-op when unsupported.

## Design guarantees
- No kernel-header dependency: MSR ioctls defined locally.
- PIE-safe CPUID (ebx-routed) so binaries never corrupt the GOT.
- Every write is: probe capability -> validate envelope -> execute -> verify.
- If MSR is inaccessible, degrades to sysfs; if neither, returns a clean error.
- 100% local, zero network, zero cloud. GitHub MIT OSS.

## Safety & liability
These operate hardware outside factory spec. All writes must pass the shared
`os/hardware-tech/lib/hardware-consent.sh` gate (explicit user acceptance,
logged locally, append-only). See that file for the consent flow.
