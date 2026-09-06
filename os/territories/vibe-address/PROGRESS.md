# TinkerOS v1.2 — MASTER PROGRESS / TODO (updated continuously)

Legend: [x] done   [~] in progress   [ ] pending

## Global project tracks
[x] Local repo http://github.com/Aghosh-mv/TinkerOS created + code pushed (520 files, os/ + kernel/tinker + README)
[x] SourceForge project tinkeros exists (aghoshpratheesh) — ISO upload target
[ ] Upload 10GB+ ISO to SourceForge + confirm download-page link
[ ] Verify GitHub README download block points to the confirmed SourceForge link, re-push if needed
[ ] Searchie installed inside TinkerOS (bind-f7 + autostart in the ISO rootfs)

## v1.2 ISO build track
[~] Kernel 7.2.0-rc6 + gamemode hook built & placed in ISO (vmlinuz)          ~95%
[x] Rootfs fully populated (desktop + worlds + voKK + dev/game/hack tools)
[~] Squashfs recompression of expanded rootfs (target >10GB ISO)
[ ] Final xorriso iso-level 3 assembly (replace current 8.8GB ISO)
[ ] ISO self-test: file / du / strings vmlinuz / unsquashfs voKK+world tools
[ ] Upload to SourceForge + link README

## Searchie (vibe addressing) track — target 10k+ lines pure-algorithm
[x] Engine kernel modules present (tree/time/ingest/bulk/index/match/rank/query/adapt/store)
[x] Container: record/bulk/ask/planner/tree/stats/optimize/session/bootstrap
[x] First-boot bootstrap sweep (file/media/shell-history/recents/browser-history/bookmarks/apps)
[x] Batch pipeline: O(lines) loading, no per-event subprocess spawn
[~] Live accuracy loop end-to-end verified (record -> ask -> ranked table)    ~70%
[ ] Searchie launcher UI (Tab+F7 overlay, type to filter, ms response)
[ ] Synonym ring + fuzzy expansion for VERY undetailed requests ("that thing")
[ ] Time-lattice day-bucket pruning wired into candidate fetch (big-index speed)
[ ] Deep-category auto-deepening (derived branches from ambiguity)
[ ] Persist query/result feedback into adapt weights + demo convergence
[ ] Line-count gate: >10k lines engine + launcher (verify wc -l)
[ ] Bake into ISO + document

## Standing rules (do not break)
- 10GB ISO is a MINIMUM floor, NO ceiling — bigger (15/20/30GB+) is great if justified; no padding
- GitHub = text/code/ad only. ISO NEVER uploaded to GitHub. Only links.
- No mention of "Spotlight" anywhere in Searchie branding/README/docs.
- This box is BUILD-ONLY. Never install Searchie/shortcuts targeting this machine.