# PReduce Track 4 PIR — Cost-Guided Extraction

**Date**: 2026-06-10 · loop iterations 27-32 · commits `f81820e8`..(close)
Written against POST_IMPLEMENTATION_REVIEW.org's 16 questions.

## §1 Stated objectives
Extraction as a propagator fixpoint on the e-class poset; the SM6 question-keyed
store; residuation as 1B's first consumer; the chartered payoff A/B.

## §2 Delivered
extraction.rkt (the Q interface per owner D7; per-canonical lazy cost cells;
refireable recompute propagators; the pure argmin read; extract/budgeted via
tropical-left-residual) · extraction-store.rkt (the cache lattice, content-
defined question keys, zero-allocation hits) · the parent-descriptor index ·
~40 new checks · the crossover investigation.

## §3 Timeline
Six iterations: design 2, fixpoint 1, store 1, residuation 1, A/B + close 1.

## §4 Deferred (named)
The consult-wiring of extract/cached into the δ/β READ path (extraction exists
but the ingestion hooks don't yet ASK it); SELECTIVE ingestion (the data-pointed
lever — see §15); the parent-keyed second index projection; Q-generic store
merge; per-level residual pruning under partial costs; .pnet e-class sections
(Track 5).

## §5 What went well
The fixpoint design survived contact: cost cells + refireable watchers + one
quiescence call. The store's zero-allocation hit is exactly the contract the
cache-lattice framing promised. Residuation slotted in as three lines over a
ten-line algebra.

## §6 What went wrong
Two e-graph fundamentals had to be gate-learned (literal-only seeding;
canonicalize-every-identity — #17/#18); the first A/B corpus premise was
FALSIFIED in one run (defs evaluate eagerly; references add no reduce work) and
the second (repeated calls) revealed that top-level evaluation doesn't route
heavy work through the instrumented path at testable scale.

## §7 Where we got lucky
':canonical existing as the min-alloc total order made canonicalization a
lookup, not a union-find traversal.

## §8 What surprised us
The corpus falsifications taught more than a confirming benchmark would have:
the repeated-work surface in THIS pipeline is narrower than e-graph folklore
assumes (eager defs; fast native evaluation paths) — the memo's true target is
elaboration-driven re-reduction (ppn-track4c's 1136ms reduce phase), which the
blanket hook's overhead currently negates.

## §9 Architecture hold-up
Held. The fixpoint is cells+propagators+quiescence; the store is a declared
derived lattice; residuation is pure reads; the two gate-caught fundamentals are
now enforced by construction. Named deviation: cost cells allocate on the prn
per request without reclamation (monotone garbage, the documented class).

## §10 What this enables
Track 5's persistence has a store worth persisting; the SELECTIVE-ingestion
follow-on has its instruments; Track 8's retirement case has extraction as the
serving path once consult-wiring lands.

## §11 Technical debt (named)
The descriptor scan in reachable-canon (O(all descriptors) per extract); the
v1 datum/expr form split (now THREE form kinds: seed datums, expr forms,
enode vectors — unification pressure is real); extraction's cost cells never
participate in congruence (correct today, audit when ι lands).

## §12 What we'd do differently
Run the corpus falsification FIRST (one driver run each) before designing the
A/B around an assumed workload shape.

## §13 Wrong assumptions
"Def references re-reduce" (eager); "repeated calls produce heavy instrumented
reduce work at small scale" (native evaluation is fast; the phase attribution
lives elsewhere).

## §14 What we learned
Extraction's machinery is the EASY half; the payoff lives entirely in WHERE
ingestion happens. The floor (+52µs/position) times the fresh-position count is
the whole story of the current negative verdict — selectivity, not machinery,
is the lever.

## §15 Are we solving the right problem?
The machinery: yes, and it is done. The deployment: the flip criterion is
STILL not met — the honest chain now reads: blanket ingestion costs more than
the memo recovers on every corpus in hand; the memo's marginal cost for
repeated identical redexes is ~0 (proven in deltas); therefore the named
follow-on is SELECTIVE ingestion (δ/β-only; size-thresholded; or
consult-extraction-on-read) measured against ppn-track4c's 1136ms reduce
phase — plus Track 5's cross-file reuse where the question-keyed store
multiplies hits. The curve has NOT turned; the levers that could turn it are
now specific, instrumented, and cheap to test.

## §16 Longitudinal
The Track 2 PIR's "totality at gated match clauses" gains no new points (no
new gates this track). NEW: "falsify the workload premise before building the
benchmark" (2 data points in one track — the def-reference and repeated-call
corpora; codify-candidate at the next occurrence). #17/#18 (seeding,
canonicalization) join the precision-as-soundness family as e-graph-specific
soundness contracts, codified in-code.

## Metrics
6 iterations · 4 code commits · ~40 checks (diamond, cascade, literal-beats-
node, determinism, zero-alloc hits, criterion isolation, keep-better both
ways, residual algebra) · the A/B: ON +130ms standing overhead on the
acceptance at every workload weight tested; memo marginal ~0 on repeats.

## Key files
extraction.rkt · extraction-store.rkt · eclass-graph.rkt (parent index) ·
tests/test-extraction.rkt · the Track 4 design doc.
