# TinkerOS — GENUINE Novel Ideas (honest log)

This file separates what is genuinely NEW-generation from what is
derivative (known tech rephrased). It is deliberately self-critical:
anything that is really "an OS already has this" is marked [D], and only
ideas with a genuinely novel angle are [I] / [N] (N = next-gen).

---

## Part A — TRULY new-generation concepts (the real novel ones)

### [N] 1. Software-Defined GPU abstraction INSIDE the OS (no GPU, no cloud)
Not "software rendering" (that exists). The novel angle: a kernel
device `/dev/tinker-gpu` that emulates the GPU *architecture & interface*
— command buffers, a software "warp/wavefront" scheduler that packs small
parallel tasks into wide CPU-SIMD batches, unified memory paging shared
with the CPU — so existing GPU-oriented software can talk to "a GPU" that
is actually the OS exposing CPU parallelism as a genuine GPU-shaped
hardware abstraction. Buildable, novel, and we actually own a `sdgpu.c`
kernel module in kernel/tinker as a starting seed.
Status: [N] concept, seed module present.

### [N] 2. Consent-as-a-syscall (intent-capability tokens, not permissions)
Modern OS grant access via DAC/ACL/capabilities — static, inherited,
long-lived. The novel construct: a syscall family where an access grant is
an **ephemeral, single-intent capability token** minted at the exact moment
a human confirms an intent (a file-picker click, a device chooser, a paste).
The kernel hands out a short-lived token bound to that one intent; it
cannot be forwarded, inherited, or reused. This inverses security from
"what may you access" to "what did you just intend." Deeply novel, and ties
into our portal-sandbox + A6 invisible sandboxing.
Status: [I], design-level.

### [N] 3. Thermal PRE-scheduling (predict heat before it exists)
All thermal governors are *reactive* — they observe heat and react. Novel:
use app launch + historical load-phase telemetry to predict a CPU spike
BEFORE it forms, then pre-cool, pre-downshift, or pre-fetch *ahead* of the
spike (proactive cooling scheduling). We have thermal_sched.c +
predictive_prewarm.c to build this on. Different from anything shipped.
Status: [I], ties to real kernel modules.

### [N] 4. AI-native core scheduler rewrite (predictive task placement)
Beyond "ML picks a CPU" — a deep core scheduler whose task placement and
preemption are driven by a predictive model of each workload's realtime
phase (not just priority + load), learned continuously from the process's
own execution pattern. This is the big pending kernel task (MASTER_TODO J).
Status: [P] pending deep work; genuine, ambitious, unbuilt.

### [N] 5. The mode-world CONTAINMENT itself as an OS primitive
Most OS "multi-profile"/"kiosk" systems are login-level. Novel: the
HACK/NORMAL/GAME world matrix is a first-class kernel+session primitive
where **process/app ownership is world-scoped and cross-world access is
denied at the syscall layer**, with per-world file/network/execution
namespaces, plus switchable realtime optimization per world. i.e. living in
three OSes in one, with strict world boundaries enforced by the kernel.
Status: [I→P], the territory engine is the working seed.

---

## Part B — Genuinely new but narrower (still non-obvious)

### [I] 6. Self-heating prediction tied to app phase patterns
Predict thermal ceiling from the *specific phase* of a running workload
(compile phases, game map-load, render bursts) rather than raw load.
Feeds idea #3. Novel sub-angle.

### [I] 7. Hardware-intent layer (hardware_dna) — device-use intent logging
Not just "who used the camera" (that exists) but mapping hardware access to
*user intent windows* so anomalies = access OUTSIDE an intent window.
Reframes hardware monitoring from whitelist to intent-vs-outer baseline.

### [I] 8. Supply-chain "provenance merkle log" per package install
Package managers check hashes (exists). Novel: a tamper-evident *merkle
provenance chain* per installed package that a future attacker must break
coherently across ALL installations — a global integrity lattice rather
than per-package checksums.

---

## Part C — SELF-CRITICAL review: ideas that are NOT novel (honest)
- Predictive resource pre-allocation (PSI/TRM) — derivative: OSs/hotspots
  already do temporal + launcher preload.
- Context-aware adaptation (CSS) — derivative: auto-tuners/modes exist.
- Most of the 45 territory tools map to existing classes (firewall = nft,
  vault = LUKS/encfs, allowlist = AppArmor/SELinux, replay = OBS addons,
  save-sync = cloud/git backups, biometric = PAM fingerprint, etc.).
  They are valuable INTEGRATIONS and theming, not novel tech.

---

## Honest bottom line
The genuinely NEW-generation, buildable contributions in this project are:
  #1 Software-Defined GPU abstraction (sdgpu seed exists)
  #2 Consent-as-a-syscall intent tokens
  #3 Thermal PRE-scheduling (predictive, not reactive)
  #4 AI-native predictive core scheduler (deep pending work)
  #5 World-matrix containment as an OS primitive
  #6-8: narrower novel sub-angles.
The 45 territories + boot/login theming are real, functional, and build on
real Linux — but as a class they are integrations of known tech, not new
paradigms. This file keeps that distinction explicit.
