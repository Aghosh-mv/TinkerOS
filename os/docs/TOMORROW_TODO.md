# TinkerOS — Master TODO / Tomorrow's Queue
*(Saved session state, 2026-09-07)*

## Completed Today
1. **Searchie Algorithmic Core Additions**:
   - Aho-Corasick automaton (`core/auto.sh`) + zero-hit substring rescue.
   - Count-Min Sketch frequency oracle (`core/cms.sh`).
   - Edit-Distance Automaton / Banded Levenshtein (`core/dista.sh`) + L3 typo-rescue tier.
   - Rocchio Pseudo-Relevance Feedback (PRF) re-ranker (`core/prf.sh`).
   - Markov-chain next-token predictor (`core/markov.sh`) trained on ingest.
   - MinHash & Banded LSH near-duplicate detector (`core/lsh.sh`).
   - Character Suffix Array infix search (`core/sarray.sh`).
2. **First-Party App Adoptions & Marketplace Fixes**:
   - Adopted `aether-by-tinkerOS` and `nibra-betterlife` into `os/apps/apps/`.
   - Fixed tinker-market.py shell injection + SQLite Python 3.14 compatibility (`python3.11`).
   - Seeded first-party apps idempotently.
3. **Infrastructure & Push Fixes**:
   - Built content-filter toggle (`os/system/content-filter.sh`).
   - Removed 8.9GB ISO from git tracking (`.gitignore`).
   - Purged large binary blobs from history via `filter-branch`, resolving GitHub HTTP 500 pushes. Successfully pushed all commits to `origin/master`.

---

## TODO for Tomorrow
1. **Searchie Integration & Polish**:
   - Wire Suffix Array search into the `ve_query_fetch_candidates` relax cascade as an L2.7 fallback tier.
   - Add MinHash duplicate pruning option during retention/optimize sweeps (`ve_store_optimize`).
2. **Real Kernel Integration**:
   - Continue wiring `kernel/tinker/` hint modules (gamemode, thermal, energy) into active scheduler and cpufreq governor paths.
3. **ISO Packaging**:
   - Run local build checks for the TinkerOS ISO build script (ensuring external assets point to SourceForge / proper remotes).
