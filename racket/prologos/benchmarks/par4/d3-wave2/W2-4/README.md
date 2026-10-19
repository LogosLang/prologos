# W2-4 (production-defect settler) — probes and outputs

Scratch: /Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-4/
Code measured: worktree par4-arena-executors @ 07fe9a12 (racket/prologos identical to main c1f389ab; `git diff --stat c1f389ab HEAD -- racket/prologos ':!benchmarks'` touches only data/par4-p0/o3).
No rebuild; nothing written to the repository. One Racket process at a time. Load during runs: 3.6–6.9 (uptime; other agents active) — all results are counts, not timings.

Harnesses
- w24-run.rkt FILE.prologos — numbered results + `W24 {json}`; env STRAT=auto|dfs|atms, EXEC=prod|seq, OUTER=1, NONFIX=1, RACE=1, PERFCHAP=1, ROUTES=1.
- w24-test.rkt TEST.rkt (STRAT override around a test module), w24-test-race.rkt, w24-test-outer.rkt.
- compare.py / q1-classify.py — answer-multiset comparison (gensyms normalised).

Q1 PD-1: q1-run.sh -> q1/*.{auto,dfs,atms}.out ; reach/reach-*.prologos -> reach/*.out ; q1t/*.out (tests under overrides) ; q1t/weak-pin.rkt
Q2 PD-3: q2/q2-power.rkt -> q2/q2-power.out, q2-power-iter1.out ; q2-tier.sh -> q2/tier/ ; q2-all.sh -> q2/all-summary.txt ; w24-test-race.rkt -> q2/tests/ ; q2/nondet/track6.*.out
Q3 PD-2: census-fireonce.sh ; q3-tier1-sweep.rkt -> q3/*.sweep.out ; NONFIX=1 runs -> q3/inrun/ ; q3-cell1.rkt -> q3/cell1-*.out, q3/cell26-truths.out
Q4 PD-5: q4-power.rkt -> q4/q4-power.out ; q4-run.sh -> q4/summary2.txt (q4-agg.py) ; q4-tests.sh -> q4/tests-summary.txt
Failed method (recorded): mk-inst.py + inst-loader.rkt + t1-inst.rkt — an instrumented in-memory copy of propagator.rkt cannot link with the compiled dependents (keyword-procedure core names such as net-new-cell-widen158.1 differ per compilation).
