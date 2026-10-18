# W2-2 (P2-lite settler) — results, PAR 4 D.3 wave 2

Scratch copy: `git archive HEAD racket/prologos tools` of worktree par4-arena-executors at 07fe9a12 (racket/prologos identical to df80be74 / main c1f389ab).
Variant switches (env, read at module load; ONE build, PLT_CS_COMPILE_LIMIT=1000000 raco make -j 4): see `w22-variants.patch`.
- W22_EXEC_OFF=1 — driver.rkt:567 does not install make-parallel-thread-fire-all (BSP uses sequential-fire-all).
- W22_KEYED_DIFF=1 — net-cell-write slow path (propagator.rkt:2073 at HEAD) diffs only the written value's keys for merges registered key-preserving (attribute-map-merge-fn).
- W22_DELTA_WRITES=1 — BSP fires carry the joined delta of their attribute-map writes instead of the whole post-fire map (chain-checked, falls back to the whole map).
- W22_KEYED_MONITOR=full, W22_KEYED_POWER=1, W22_DW_POWER=1 — equivalence monitors and their power rows.

Timing: process-file wall after an in-process preload (`w22-time.rkt`), 5 reps per process, 18 comparative files
(parity-adversarial excluded: DEFERRED 153 crash at HEAD), legs rotated per round, each round under the suite lock.
t1 = legs A–D × 8 rounds (1-min load 2.49–3.87); t2 = legs A–E × 8 rounds (load 3.75–7.01).

| ms (median of 8 process medians) | A as-is | B exec off | C keyed | D both | E both+delta |
|---|---|---|---|---|---|
| constraints-adversarial t1 | 66.3 | 44.1 | 54.7 | 30.0 | |
| constraints-adversarial t2 | 71.5 | 46.8 | 58.3 | 31.4 | 20.7 |
| type-adversarial t1 | 63.5 | 40.9 | 56.1 | 32.1 | |
| type-adversarial t2 | 67.1 | 43.1 | 58.8 | 35.1 | 26.6 |
| medium 18 sum t1 | 245.4 | 192.2 | 226.9 | 167.8 | |
| medium 18 sum t2 | 259.6 | 202.6 | 238.8 | 181.7 | 157.4 |
| other 16 sum t2 | 121.1 | 112.6 | 121.7 | 115.2 | 110.2 |

Monitors (19 files, one per process): keyed vs full diff 2992/2992 eligible writes compared, 0 mismatches (executor off and on);
power (drop one key) 1980/2992 caught. Delta-carried writes: 1034 carried, 0 chain fallbacks, 2 merged-value mismatches
(type-adversarial, :type classifier meta1890 vs meta1889); power 857/1034 caught. Output fingerprints: a wrong keyed diff
changed NO deterministic file's printed results (pw/legs.jsonl) — outputs have no power; only the per-write monitor does.

Q4 single instrument: `split/model.txt`.
