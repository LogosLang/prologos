# PReduce Track 3 PIR — ι/DPO

**Date**: 2026-06-10 · loop iterations 40-42 · against the 16-question checklist.

## §1-§2 Objectives / Delivered
The coverage multiplier. Delivered: the §0 blocking verification RESOLVED
(catch-alls do not survive compile-match-tree — no NAC machinery exists to
build; the revisit clause never fires); ι hooks on the natrec recursion
carriers (#:compute verified verbatim; the guard extended); the coverage A/B.
Phase 2 (user expr-reduce metadata) DESCOPED as moot-for-payoff (named, not
silent — it adds registry completeness, not measurement; it can ride any
later track).

## §3 Timeline
Three iterations: opener+verification 1, the hook 1, the A/B + close 1.

## §4-§8 Deferred / Well / Wrong / Lucky / Surprised
DEFERRED: Phase 2 metadata; boolrec/listrec arms (moot by the same verdict).
WELL: the blocking verification dissolved in ONE static trace after two
runtime-probe dead-ends. WRONG: the weak-head test expectation (the hook was
right). LUCKY: the compiler already being pattern-complete erased Track 3's
hardest design question. SURPRISED: ι coverage at the recursion carriers is
WALL-CLOCK-FREE — and wins nothing (see §15).

## §9-§14 Architecture / Enables / Debt / Differently / Assumptions / Learned
Architecture held (the δ mechanics carried ι unchanged — three rule kinds, one
memo mechanism). ENABLES: the SH/Zig dossier (§15). LEARNED: memoizable redex
RECURRENCE is the binding constraint, not coverage — unique-per-instance
redexes dominate real reduction; the e-graph's economics need either cheap
interning (lowering) or workloads with genuine cross-instance sharing.

## §15 THE SERIES VERDICT (the pre-registered boundary fires)
The coverage A/B: OFF/DB/WARM all within noise on both files (341/342/341ms;
1573/1575/1570ms). With ι at the recursion carriers, ingestion is FREE — a
full e-graph recording layer at zero marginal wall-clock — but the memo's
value never exceeds its cost on this substrate at these workloads. PER THE §4
PRE-REGISTRATION: the suspect is the per-position floor (+52µs intern+dispatch
— pure Racket allocation/hashing), and THE ANSWER IS LOWERING (SH/Zig), not
more Racket-side coverage. The Racket-side coverage chapter CLOSES with a
complete dossier: the architecture works (every mechanism proven), the
recording is free, the floor is characterized, and on a substrate where
intern+dispatch costs ~ns the same economics invert. This is the LLVM-lowering
case, handed to SH with numbers.

## §16 Longitudinal
"Falsify the workload premise" earns its 3rd point (the preliminary +66ms
glance dissolved under 5-run medians) — CODIFY at the next rules-file commit.
The static-trace-vs-runtime-probe judgment lesson recurs (2nd point).

## Metrics
3 iterations · 2 code commits · the verification (1 static trace) · the A/B
(30 runs): all modes within noise; recording layer wall-clock-free.

## Key files
reduction.rkt (the ι clauses) · the Track 3 design doc (§0 the verification) ·
tests/test-preduce-ingest.rkt.
