# TinkerOS — Master TODO / Tomorrow's Queue
*(Saved session state, 2026-09-08)*

## Completed Today
1. **Searchie: Suffix-Array L4 tier finished** (`core/sarray.sh`, `core/query.sh`):
   - Fixed `ve_sarray_owner` field-order bug (`fp|start|end` vs `start|end`).
   - Fixed `local a=.. rest=.. b="${rest..}"` set-u shadow-bind in owner.
   - Fixed `ve_sarray_ensure` ending with `[ x ] && rebuild` (rc=1) killing search under
     `set -e` → wrapped in `if`. Search now returns fps correctly (beach/ott/zzz verified).
   - SA infix tier (`ve_query_fetch_sarray`) is now L4 in the relax cascade (L0..L6);
     "ott"→beach_photo.jpg resolves via infix, message threshold `relax_level -le 4`.
   - 3 new selftest probes (ensure idempotent, infix hits, absent reject). 42 checks.
2. **Searchie: LSH dupe-scan** (`core/lsh.sh`, `core/store.sh`, `vibe-address.sh`):
   - `ve_lsh_dupe_scan` store-wide report "fpA|fpB|rows"; `ve_lsh_dupe_count`.
   - `dupes` command (candidate pairs report, non-destructive).
   - `stats` shows signature count + near-dup pairs; `optimize` reports dupe count.
   - Verified end-to-end (identical→8/8 pair found; near-copies share only 2 rows — inherent
     to char-trigram LSH). 1 new probe. 43 checks.
3. **Searchie: audit/audit-query** (`core/audit.sh` new module, dispatcher):
   - `audit <fp>` dumps envelope, name/source/category tokens, per-token df+postings,
     BM25 doclen+doccount, suffix-array window, markov orders, minhash signature,
     CMS estimate, retention standings.
   - `audit-query <words>` prints the full L0..L6 relax ladder with candidate counts.
   - Many set-e/pipefail guards added inside probe paths. 2 probes. 45 checks.
4. **Real Kernel: GameMode × thermal scheduler integration**:
   - `kernel/tinker/gamemode.c`: new `tinker_task_boosted(struct task_struct *)` probe
     (checks current boosted tgid under gamemode_lock). EXPORT_SYMBOL_GPL.
   - `kernel/tinker/tinker_core.h`: prototype + `struct task_struct;` fwd decl.
   - `kernel/sched/fair.c` `select_task_rq_fair`: before the existing thermal-demotion
     block, boosted task → skip thermal demotion, stay affine fast path
     (`select_idle_sibling(p, prev_cpu, new_cpu)`), guarded by
     `IS_ENABLED(CONFIG_TINKER_GAMEMODE)`.
   - Verified: `make kernel/tinker/gamemode.o kernel/sched/fair.o` clean; **full `vmlinux`
     link passes** → symbols resolve, kernel boots-linkable.

## TODO for Tomorrow
1. **Searchie alignment/shortlist**:
   - `vibe:align` — force-rebuild consistency of bloom / ac / wider (dista dictionary) /
     sarray / markov / lsh from the event store (audit-style model integrity check).
   - Add per-tier hit *explanation* lines to RESULT output (which tier produced it).
2. **Optimize sweep using LSH dupe list**: `optimize` optionally reports/prunes exact-dup
   pairs surfaced by dupe-scan (still non-destructive by default).
3. **cpufreq governor integration**: wire `tinker_gamemode_enabled()` into the schedutil
   fast-switch path (raise util for boosted runs) — real code in `kernel/sched/cpufreq_schedutil.c`.
4. **ISO packaging smoke-test** pointing external assets at SourceForge remotes.