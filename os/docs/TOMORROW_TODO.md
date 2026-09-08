# TinkerOS — Master TODO / Tomorrow's Queue
*(Saved session state, 2026-09-08)*

## Completed Today
1. **Searchie: Suffix-Array L4 tier finished** (`core/sarray.sh`, `core/query.sh`): fixed
   field-order + set-u shadow-bind + `[ ] && rebuild` errexit kills; SA infix now L4 in the
   relax cascade (L0..L6); "ott"→beach_photo.jpg via infix; 42 checks.
2. **Searchie: LSH dupe-scan** (`core/lsh.sh`): `ve_lsh_dupe_scan`/`ve_lsh_dupe_count`,
   `dupes` command, stats+optimize wiring; near-copies share 2/8 rows (char-trigram); 43.
3. **Searchie: audit/audit-query** (`core/audit.sh`): full per-event dump + L0..L6 query
   ladder; 45.
4. **Real Kernel: GameMode × thermal scheduler**: `tinker_task_boosted()` probe + fair.c
   fast-path override (boosted tasks waive thermal demotion, stay affine); vmlinux link
   passes; 2ca0d9de3.
5. **Real Kernel: schedutil GameMode P-state boost** (`kernel/sched/cpufreq_schedutil.c`):
   `sugov_tinker_gamemode_util()` adds util headroom while a `tinker_task_boosted(current)`
   task runs on a CPU, in BOTH single-CPU freq + perf update paths; runtime knob
   `/sys/module/cpufreq_schedutil/parameters/tinker_gamemode_util_step` (module_param uint,
   0644, 0 disables); vmlinux link verified.
6. **Searchie: align auditor + optimize --burn** (`core/align.sh` + store/index/markov/sarray/
   lsh/sh): `align [check|--fix]`; fixed EAGER store-dir bindings in markov+sarray (lazy now
   — selftest was writing to the real user store), clean-room `ve_index_rebuild` (fp table +
   source/type/time tokens + time buckets; fixed unbound `$source`), `ve_store_append`
   self-mkdir; `optimize --burn` quarantines 8/8-row same-token duplicates into
   `events/.dupes/`; 48 checks.
7. **Searchie: tier explanations in query results**: `ve_query_tier_label()` — results now
   say WHY they matched ("strict inverted-index hit" | "relaxed to informative/substring/
   edit-distance/infix/category+time/recency"); 49.
8. **ISO packaging smoke-test** (`os/iso-builder.sh`): builder required pre-made GRUB
   `bios.img`/`efi.img` but never generated them → added `create_boot_images()` (bios.img via
   `grub-mkimage -O i386-pc`, efi.img via FAT16 + `grub-mkimage -O x86_64-efi` + mtools, no
   sudo); fixed nonstandard `-eltorito-efi` → `-e`; mtools/grub-common in deps. **Verified**
   on this host: full bootable ISO assembled with xorriso, El Torito catalog + BIOS image +
   UEFI image confirmed (`-report_el_torito`). 50.
9. **Searchie: bloom sweep check**: `ve_bloom_rebuild` missing `local pf` fixed; selftest
   probe asserts rebuilt filter admits indexed tokens and rejects absent ones; 50 checks.

## TODO for Tomorrow
1. **TIO/TUI polish**: markov chain completion phrases for the overlay; `markov` command
   regression after lazy-dir fix.
2. **align `--fix` dry-run**: `align [--fix --dry-run]` shows what WOULD be rebuilt before
   touching the store.
3. **Searchie: session timeline / `timeline` command** (per-day event counts, last-seen fps).
4. **TinkerOS: desktop integration** — decktop entry for Searchie overlay (Tab+F7 launcher),
   Plymouth + GRUB branding pass for the ISO.
5. **Gamescope/Proton GameMode hinting**: tinker gamemode proc API (`/proc/tinker/gamemode`)
   already exists — bump the user-space `gamemode-setup` tool to drive it during a game session.