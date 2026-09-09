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
   on the SF account): `SF_USER=<account> ./os/publish-iso.sh TinkerOS-v1.2.iso`; generate
   SHA manifest with `os/iso-artifacts.sh`; README already links the SF project page.
   Never git-commit the ISO.
2. **Rebuild branded ISO**: stage2b_branding (plymouth + TinkerOS splash/GRUB theme) golden
   bake in-flight → produces final ~8.5 GB `TinkerOS-v1.2.iso`; verify El Torito, then publish.
3. **TIO/TUI polish**: markov chain completion phrases for the overlay; `markov` regression.
4. **Kernel: crash-safe gamemode reap DONE** (boost clears if the boosted process group died).