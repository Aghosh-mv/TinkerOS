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
5. **Real Kernel: schedutil P-state boost** (`kernel/sched/cpufreq_schedutil.c`):
   - New `sugov_tinker_gamemode_util()`: while a `tinker_task_boosted(current)` task runs on
     a CPU, the single-core update path adds a +256 util step (clamped to `max_cap`) before
     mapping util→frequency, in BOTH the freq (`update_single_freq`) and perf
     (`update_single_perf`) paths. Game threads hold the high-frequency floor rather than
     ramping down as load eases.
   - `sugov_hold_freq`/slack preserved (boost applied after hold logic). Objects + full
     `vmlinux` link verified.
6. **Searchie: align auditor + optimize --burn** (`core/align.sh`, `core/store.sh`,
   `core/index.sh`, `core/markov.sh`, `core/sarray.sh`, `core/lsh.sh`):
   - `ve_align_check` (index/fp/time, inv-refs, bloom, sarray, markov, lsh vs store;
     ALIGNED/DRIFT; lazy artifacts report N/A not corruption) + `ve_align_fix`
     (clean-room rebuild + event replay) + `align [check|--fix]`.
   - Fixed **eager store-dir binding** in `markov.sh` + `sarray.sh` (dirs resolved lazily at
     call time — selftest sandbox was silently writing to the real user store, which broke
     in-harness alignment: owners=0, order files=0).
   - `ve_index_rebuild` clean-room (clears fp table) + re-derives source/type/time tokens
     (was silently dropping them) + re-inserts time buckets; fixed unbound `$source`.
   - `ve_store_append` self-`mkdir -p "$VIBE_EVENTS"`.
   - `optimize --burn <store>`: LSH 8/8-row pairs with equal name tokens are quarantined
     (moved to `events/.dupes/`, never deleted); index/bloom/sarray/lsh rebuilt after.
   - Selftest: 48 checks.

## TODO for Tomorrow
1. **align/audit explanation UI**: add per-tier hit *explanation* lines to `RESULT` output
   (which tier produced which hit).
2. **bloom filter on optimize --burn path**: verify bloom is emitted for the quarantined
   fps too (post-burn rebuild covers it — sweep to confirm no stale admission for burned fp).
3. **cpufreq governor tuning knobs**: make `TINKER_GAMEMODE_UTIL_STEP` configurable via
   `/sys`/debugfs (runtime, not compile-time).
4. **ISO packaging smoke-test** pointing external assets at SourceForge remotes.