# W2-3 — detector protocol settler (PAR 4 D.3 wave 2): probes and outputs

All files in this directory; nothing written in the repository.

| probe | what | output |
|---|---|---|
| `w23_model.py` | the exhaustive model engine: K = 2–3 executors + detector; local cascades; counted / uncounted / missing fire requests; contradiction stop with three boundary rules; regions keyed by network id (concurrent and nested); memory SC / TSO (store buffering: a store may pass the thread's later loads unless a FENCE drains the buffer) / PSO (stores to different addresses also reorder); every shared load/store is a step; checks PREMATURE, WRONGFIX, STALE (handler read), RACE (write after a contradiction boundary), LIVE (AG EF boundary), and the late-write check (MISSED / CAUGHT) | — |
| `w23_run.py q1 power` | Q1 reproduction; power rows | `w23_q1_power.out` |
| `w23_run.py contra regions late log` | contradiction stop; regions; late-write check; lanes as logs | `w23_contra_regions_late_log.out` |
| `w23_run.py matrix` | every repair × workload × memory (D2 rows in `w23_matrix_D2_partial.out`) | `w23_matrix.out` |
| `w23_run.py supplement` | PSO with both releases; unordered detector reads (ARM load-load reordering); re-runs after fixes | `w23_supplement.out` |
| `w23_onepass.py` | one-pass counting detector (all cons, then all prod) + its power rows | `w23_onepass.out` |
| `w23_flagd.py` | D.1 §5.4 read literally ("cons = received and processed") | `w23_flagd.out` |
| `detect-w23.rkt` | copy of `benchmarks/par4/detect.rkt` + D.2-shaped DIRECT loop + CASCADE/CASCADE2 rows + modes d2 flag act quiet defer seeds seeds1 logseeds logseeds1 credit + premature counters + watchdog | `detect-w23.out` (WORK=20 all rows, WORK=1000 cascade rows), `detect-w23.drain.out` (DRAIN=every vs idle, head-store artefact removed), `detect-w23.WORK20.out` (first run: K=2 complete, K=4 hung once before the watchdog existed) |
| `detect-orig.rkt` | unmodified copy of `benchmarks/par4/detect.rkt` | — |

Timing runs: under `benchmarks/par4/hold-suite-lock.rkt` (exclusive suite lock), modes interleaved within each of 7
repetitions, my own model processes paused (SIGSTOP by PID) during the runs; `uptime` load 4.85–6.35 from other
sessions (18-core Apple M5 Max, Racket 9.3 CS).
