# C10 (value & scope) — probe results, HEAD = worktree par4-arena-executors (racket/ = main c1f389ab)

Racket 9.3 CS, M5 Max, load 2–3.5. One .prologos file per process; prelude preloaded; .pnet writes disabled.

## hub-probe.rkt (BSP observer; K=8 round-robin; D.2 §6.7 home rule = owner of first declared output)

| | constraints-adversarial | type-adversarial |
|---|---|---|
| fires | 1136 | 1140 |
| fires per executor (K=8 RR) | 19,1015,13,17,12,21,22,17 | 42,966,14,15,17,10,50,26 |
| busiest executor share | 0.893 | 0.847 |
| parallelism bound (fires / busiest) | 1.12x | 1.18x |
| fires whose first output is the attribute map | 1006 (88.6 %) | 952 (83.5 %) |
| attribute-map size N at write (p50/p90/max positions) | 352/570/620 | 235/467/500 |
| changed paths per fire write (p50/p90) | 1/2 | 1/2 |
| pu-value-diff on real (old,new) pairs | 23 821 ns | 16 494 ns |
| delta-keyed diff, same pairs | 83 ns | 78 ns |
| outputs equal (keyed vs full) | 224/224 | 203/203 |
| power: keyed diff missing one key mismatches | 224/224 | 203/203 |
| attribute-map-merge-fn(old, delta) | 137 ns | 190 ns |
| attribute-map-merge-fn(old, full map) (what bulk-merge-writes does) | 23 796 ns | 16 698 ns |
| net-cell-write attempts / changes (whole run) | 1899 / 1763 | 1968 / 1835 |

## split-probe.rkt (raw sampler stacks, 1 ms, 10 reps; two runs)

samples with the frame on the stack (run1 / run2):

| | constraints-adversarial | type-adversarial |
|---|---|---|
| process-command | 420 / 420 | 328 / 329 |
| run-to-quiescence-bsp | 326 / 336 | 208 / 210 |
| bulk-merge-writes | 188 / 201 | 100 / 98 |
| fire-and-collect-writes | 101 / 107 | 58 / 62 |
| pu-value-diff (all) | 251 / 277 | 121 / 115 |
|   in bulk-merge-writes | 116 / 139 | 33 / 33 |
|   in fire-and-collect-writes (result discarded with the snapshot's worklist) | 82 / 97 | 53 / 50 |
|   outside BSP (elaborator writes) | 53 / 41 | 35 / 32 |
| attribute-map-merge-fn (all in bulk) | 64 / 57 | 63 / 61 |

## ESTIMATES (sample shares of process-command; delta paths assumed ~0 per the ns rows above)

| change | constraints-adv | type-adv |
|---|---|---|
| P2 alone (bulk + fire ceremony removed) | ~1.9–2.0x | ~1.49x |
| P2-lite-b: diff keyed by the write's delta only | ~1.48x | ~1.35x |
| P2-lite-full: + writes carried as deltas through the round (BSP kept) | ~4.4x | ~2.2x |
| P2 marginal after P2-lite-full | <= ~1.28x | <= ~1.09x |
