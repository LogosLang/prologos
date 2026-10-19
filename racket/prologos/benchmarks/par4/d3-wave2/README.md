# PAR 4 D.3 — wave 2 evidence

The probes, outputs and verbatim returns of the ten wave-2 agents. Briefing:
`docs/tracking/tracks/PAR/PAR_4/critiques/2026-10-15_PAR_4_D3_WAVE2_BRIEFING.md`. Synthesis of record:
`docs/tracking/tracks/PAR/PAR_4/critiques/2026-10-18_PAR_4_D3_SYNTHESIS.md`.

| dir | agent | what to look at first |
|---|---|---|
| `W2-1/` | granularity settler | `results/heavy-final.txt`, `results/medium-aggregate.txt`, `gran_analyze.py`, `gran-probe.rkt`; per-fire traces are gzipped (`locked/*.json.gz`, `out/*.json.gz`) |
| `W2-2/` | P2-lite settler (built a scratch copy) | `RESULTS.md`, `w22-variants.patch` (apply to a `git archive` of `07fe9a12` with `apply-variants.py`), `t1/`, `t2/` (timed legs, gzipped), `mon/` (monitors and power rows), `split/` (sampler) |
| `W2-3/` | detector settler | `README.md`, `w23_model.py`, `w23_*.out` |
| `W2-4/` | production-defect settler | `README.md`, `reach/` (PD-1 at user level), `q2/` (PD-3), `q3*` (PD-2 and W2-4-1), `q4/` (PD-5); `inst/propagator.rkt.vs-HEAD.patch` is the instrumentation, stored as a diff against `df80be74`'s `propagator.rkt` |
| `W2-5/` | ambient-state census | `out/`, `dyn*` (fire-level differentials), `power.rkt` |
| `W2-6/` | worldview coherence | the `w26-*` models and `.prologos` probes |
| `W2-7/` | merge-row settler | `w27-*` probes and models |
| `W2-8/` | defender: K > 1 | `w28-*`, `run-bspk*.sh` |
| `W2-9/` | defender: DIRECT at K = 1 | the R-row fixtures and the E1 census |
| `W2-10/` | gap critic: UX and DX | `exec-exn.rkt` (DEFERRED 181), `u8a/u8b.prologos` (DEFERRED 182), `u*` probes |
| `raw/wave2-returns.json` | all ten returns, verbatim | parsed from the batch message (W2-1 and W2-2) and the summary files (W2-3…W2-10) |
| `_handcheck/` | my reproductions for the synthesis's §1 | `mine-crosssite.out` |

These files were run as probes. They are not tests and are not compiled by the suite. Paths inside the scripts
point at the agents' scratch directories and the worktree. To re-run one, copy it to scratch and fix the paths.
Removed before committing: empty files, W2-2's 33 MB archived tree and its `compiled/` directory, a copy of
`DEFERRED.md`, and a full copy of `propagator.rkt`, which is replaced by the diff named above.
